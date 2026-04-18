import json
import logging
import os
from contextlib import asynccontextmanager
from pathlib import Path

import boto3
from fastapi import FastAPI, Request, Response
from langchain_aws import ChatBedrockConverse
from langchain_core.messages import HumanMessage, SystemMessage, ToolMessage
from langchain_core.tools import tool

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

textract = boto3.client("textract", region_name=os.environ.get("AWS_REGION", "us-east-1"))
MODEL_ID = os.environ.get("BEDROCK_MODEL_ID", "anthropic.claude-3-5-haiku-20241022-v1:0")
AWS_REGION = os.environ.get("AWS_REGION", "us-east-1")

# classifications.json is packaged into the zip alongside agent.py
CLASSIFICATIONS_PATH = Path(__file__).parent / "classifications.json"
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
    llm = ChatBedrockConverse(model=MODEL_ID, region_name=AWS_REGION)
    llm_with_tools = llm.bind_tools([extract_text_with_textract])

    messages = [
        SystemMessage(content=SYSTEM_PROMPT),
        HumanMessage(content=f"Extract and classify the receipt at s3://{bucket}/{key}"),
    ]

    response = llm_with_tools.invoke(messages)

    if hasattr(response, "tool_calls") and response.tool_calls:
        tool_call = response.tool_calls[0]
        text = extract_text_with_textract.invoke(tool_call["args"])
        messages.append(response)
        messages.append(ToolMessage(content=text, tool_call_id=tool_call["id"]))
        final = llm.invoke(messages)
        raw_content = final.content
    else:
        raw_content = response.content

    try:
        clean = raw_content.strip().removeprefix("```json").removeprefix("```").removesuffix("```").strip()
        result = json.loads(clean)
        if result.get("category") not in CATEGORIES:
            result["category"] = "Other"
    except (json.JSONDecodeError, AttributeError):
        result = {"category": "Other", "reasoning": "Failed to parse model response."}

    return result


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("AgentCore Runtime started — listening on port 8080")
    yield
    logger.info("AgentCore Runtime shutting down")


app = FastAPI(lifespan=lifespan)


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/invocations")
async def invocations(request: Request):
    try:
        body = await request.json()
    except Exception:
        return Response(
            content=json.dumps({"error": "Invalid JSON body"}),
            status_code=400,
            media_type="application/json",
        )

    bucket = body.get("bucket")
    key = body.get("image_key")

    if not bucket or not key:
        return Response(
            content=json.dumps({"error": "Request must include 'bucket' and 'image_key'"}),
            status_code=400,
            media_type="application/json",
        )

    if not key.lower().endswith(".jpg"):
        return Response(
            content=json.dumps({"error": "Only JPG images are supported"}),
            status_code=422,
            media_type="application/json",
        )

    logger.info(json.dumps({"event": "INVOCATION", "bucket": bucket, "key": key}))

    try:
        result = classify_receipt(bucket, key)
    except Exception as e:
        logger.error(json.dumps({"event": "CLASSIFICATION_ERROR", "key": key, "error": str(e)}))
        return Response(
            content=json.dumps({"error": str(e)}),
            status_code=500,
            media_type="application/json",
        )

    logger.info(json.dumps({"event": "RECEIPT_CLASSIFICATION", "key": key, "category": result["category"]}))
    return result


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)
