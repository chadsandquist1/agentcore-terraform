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
MODEL_ID = os.environ.get("BEDROCK_MODEL_ID", "us.anthropic.claude-3-5-haiku-20241022-v1:0")

CLASSIFICATIONS_PATH = os.path.join(os.path.dirname(__file__), "classifications.json")
with open(CLASSIFICATIONS_PATH) as f:
    CATEGORIES = json.load(f)

SYSTEM_PROMPT = f"""You are a receipt classification assistant.
Given the text extracted from a receipt image, classify it into exactly one of these categories:
{json.dumps(CATEGORIES)}

Rules:
- Return ONLY a JSON object with two keys: "category" and "reasoning"
- "category" must be exactly one of the values listed above — no variations
- "reasoning" should be one concise sentence
- If the text does not appear to be a receipt, use "Not Receipt"
- If the receipt spans multiple categories, use "Mix"

Example: {{"category": "Food", "reasoning": "The receipt shows a restaurant purchase with food and beverage items."}}"""


@tool
def extract_text_with_textract(bucket: str, key: str) -> str:
    """Extract text from a JPG image stored in S3 using Amazon Textract."""
    response = textract.detect_document_text(
        Document={"S3Object": {"Bucket": bucket, "Name": key}}
    )
    lines = [
        block["Text"]
        for block in response["Blocks"]
        if block["BlockType"] == "LINE"
    ]
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

    response = llm_with_tools.invoke(messages)

    # Handle tool call if the model chose to use it
    if hasattr(response, "tool_calls") and response.tool_calls:
        from langchain_core.messages import ToolMessage
        tool_call = response.tool_calls[0]
        text = extract_text_with_textract.invoke(tool_call["args"])
        messages.append(response)
        messages.append(ToolMessage(content=text, tool_call_id=tool_call["id"]))

        # Re-invoke without tools for final classification
        final = llm.invoke(messages)
        raw_content = final.content
    else:
        raw_content = response.content

    # Parse the JSON response
    try:
        # Strip markdown code fences if present
        clean = raw_content.strip().removeprefix("```json").removeprefix("```").removesuffix("```").strip()
        result = json.loads(clean)
        if result.get("category") not in CATEGORIES:
            result["category"] = "Other"
    except (json.JSONDecodeError, AttributeError):
        result = {"category": "Other", "reasoning": "Failed to parse model response."}

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
            "category": result["category"],
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
            "category": result["category"],
            "output_key": output_key,
            "timestamp": timestamp,
        }))
