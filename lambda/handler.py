import json
import logging
import os
import time
from datetime import datetime, timezone

import boto3
from langchain_aws import ChatBedrockConverse
from langchain_core.messages import HumanMessage, SystemMessage
from langchain_core.tools import tool

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client("s3")
textract = boto3.client("textract", region_name=os.environ["AWS_REGION"])

OUTPUT_BUCKET = os.environ["OUTPUT_BUCKET"]
MODEL_ID = os.environ.get("BEDROCK_MODEL_ID", "us.anthropic.claude-haiku-4-5-20251001-v1:0")

CLASSIFICATIONS_PATH = os.path.join(os.path.dirname(__file__), "classifications.json")
with open(CLASSIFICATIONS_PATH) as f:
    CATEGORIES = json.load(f)

SYSTEM_PROMPT = f"""You are a receipt classification assistant.
Given the text extracted from a receipt image, classify it into exactly one or many of these categories:
{json.dumps(CATEGORIES)}

Return **only** a JSON object with exactly two keys:

- **`category`** — one or more values from the allowed categories list; no variations or custom values
- **`reasoning`** — one concise sentence explaining why the category or categories were selected

**Classification rules:**
1. If the text is not a receipt, use `"Not Receipt"`.
2. If the receipt spans multiple categories, include all that apply.
3. When in doubt, prefer a specific category over a general one — e.g., if grocery items are present, include `"Grocery"` even if other categories also apply.
4. Use `"Not able to classify"` only as a last resort when no other category reasonably fits.

Example: {{"category": ["Restaurant"], "reasoning": "The receipt shows a restaurant purchase with restaurant and beverage items."}}"""


@tool
def extract_text_with_textract(bucket: str, key: str) -> str:
    """Extract text from a JPG image stored in S3 using Amazon Textract."""
    response = textract.detect_document_text(
        Document={"S3Object": {"Bucket": bucket, "Name": key}}
    )
    line_blocks = [b for b in response["Blocks"] if b["BlockType"] == "LINE"]
    lines = [b["Text"] for b in line_blocks]
    avg_confidence = (
        sum(b.get("Confidence", 0) for b in line_blocks) / len(line_blocks)
        if line_blocks else 0
    )
    logger.info(json.dumps({
        "event": "TEXTRACT_RESULT",
        "bucket": bucket,
        "key": key,
        "line_count": len(lines),
        "avg_confidence": round(avg_confidence, 2),
        "lines": lines,
    }))
    return "\n".join(lines) if lines else "[No text detected]"


def classify_receipt(bucket: str, key: str) -> dict:
    llm = ChatBedrockConverse(
        model=MODEL_ID,
        region_name=os.environ["AWS_REGION"],
    )
    llm_with_tools = llm.bind_tools([extract_text_with_textract])

    messages = [
        SystemMessage(content=SYSTEM_PROMPT),
        HumanMessage(content=f"Extract and classify the receipt at s3://{bucket}/{key}"),
    ]

    logger.info(json.dumps({"event": "LLM_INVOKE_START", "bucket": bucket, "key": key, "model": MODEL_ID}))
    response = llm_with_tools.invoke(messages)

    # Handle tool call if the model chose to use it
    if hasattr(response, "tool_calls") and response.tool_calls:
        from langchain_core.messages import ToolMessage
        tool_call = response.tool_calls[0]
        logger.info(json.dumps({"event": "TOOL_CALL", "tool": tool_call["name"], "args": tool_call["args"]}))
        text = extract_text_with_textract.invoke(tool_call["args"])
        messages.append(response)
        messages.append(ToolMessage(content=text, tool_call_id=tool_call["id"]))

        logger.info(json.dumps({"event": "LLM_INVOKE_FINAL", "bucket": bucket, "key": key}))
        final = llm_with_tools.invoke(messages)
        raw_content = final.content
    else:
        raw_content = response.content

    logger.info(json.dumps({"event": "LLM_RAW_RESPONSE", "bucket": bucket, "key": key, "response": raw_content}))

    # Parse the JSON response
    try:
        clean = raw_content.strip().removeprefix("```json").removeprefix("```").removesuffix("```").strip()
        result = json.loads(clean)

        # Normalize category to a list
        raw_cats = result.get("category", [])
        if isinstance(raw_cats, str):
            raw_cats = [raw_cats]

        # Exact match first
        valid = [c for c in raw_cats if c in CATEGORIES]

        # Case-insensitive fallback
        if not valid and raw_cats:
            cats_lower = {c.lower(): c for c in CATEGORIES}
            valid = [cats_lower[c.lower()] for c in raw_cats if c.lower() in cats_lower]
            if valid:
                logger.info(json.dumps({
                    "event": "CATEGORY_NORMALIZED",
                    "raw": raw_cats,
                    "normalized": valid,
                }))

        if not valid:
            logger.warning(json.dumps({
                "event": "CATEGORY_UNRECOGNIZED",
                "raw_categories": raw_cats,
                "fallback": "Not able to classify",
            }))
            valid = ["Not able to classify"]

        result["category"] = valid
    except (json.JSONDecodeError, AttributeError) as e:
        logger.error(json.dumps({
            "event": "PARSE_ERROR",
            "error": str(e),
            "raw_content": raw_content,
        }))
        result = {"category": ["Not able to classify"], "reasoning": f"Failed to parse model response: {e}. Raw: {raw_content}"}

    logger.info(json.dumps({
        "event": "CLASSIFICATION_RESULT",
        "bucket": bucket,
        "key": key,
        "categories": result["category"],
        "reasoning": result.get("reasoning", ""),
    }))
    return result


def handler(event, context):
    for record in event.get("Records", []):
        bucket = record["s3"]["bucket"]["name"]
        key = record["s3"]["object"]["key"]

        if not key.lower().endswith(".jpg"):
            logger.info(json.dumps({"event": "SKIPPED_NON_JPG", "key": key}))
            continue

        logger.info(json.dumps({"event": "PROCESSING", "bucket": bucket, "key": key}))

        try:
            result = classify_receipt(bucket, key)
        except Exception as e:
            logger.error(json.dumps({"event": "CLASSIFICATION_ERROR", "key": key, "error": str(e)}))
            raise

        timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        output_key = f"results/{key.rsplit('/', 1)[-1].rsplit('.', 1)[0]}_{timestamp}.json"

        output_payload = {
            "source_bucket": bucket,
            "source_key": key,
            "timestamp": timestamp,
            "categories": result["category"],
            "reasoning": result.get("reasoning", ""),
        }

        s3.put_object(
            Bucket=OUTPUT_BUCKET,
            Key=output_key,
            Body=json.dumps(output_payload, indent=2),
            ContentType="application/json",
        )

        logger.info(json.dumps({
            "event": "RECEIPT_CLASSIFICATION",
            "key": key,
            "categories": result["category"],
            "output_key": output_key,
            "timestamp": timestamp,
        }))
