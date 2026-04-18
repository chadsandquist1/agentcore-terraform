# lambda/

Lambda function — the primary pipeline execution path.

## Entry Point

`handler.py` — receives S3 PUT events, runs the LangChain agent, writes results.

## Execution Flow

1. S3 PUT event arrives (JPG only — skip and log anything else)
2. Download image bytes from S3 input bucket
3. Call Textract `detect_document_text` (synchronous, single-page) to extract text
4. Pass extracted text to LangChain agent with Claude Haiku via Bedrock
5. Agent classifies receipt into exactly one category from `classifications.json`
6. Write JSON result to S3 output bucket at `results/<original_key>_<timestamp>.json`
7. Write CloudWatch log: `{"event": "RECEIPT_CLASSIFICATION", "key": ..., "category": ..., "timestamp": ...}`

## Critical Rules

- **Always read categories from `classifications.json`** — never hardcode the list in Python
- **x86_64 only** — this Lambda runs on x86_64; deps in the layer are compiled for `manylinux2014_x86_64`
- **Synchronous Textract only** — do not switch to async API (requires SNS/SQS, adds complexity)
- **Skip non-JPG** — check `key.lower().endswith('.jpg')` before doing any work; log and return on mismatch
- **Separate input/output buckets** — never write to the input bucket (infinite trigger loop)

## Files

| File | Purpose |
|---|---|
| `handler.py` | Lambda entry point — LangChain agent orchestration |
| `classifications.json` | Source of truth for receipt categories |
| `requirements.txt` | Deps installed into Lambda layer (x86_64 cross-compiled) |

## Dependencies (requirements.txt)

Installed with:
```
pip install --platform manylinux2014_x86_64 --only-binary=:all: --target ./layer/python -r requirements.txt
```

Key packages: `langchain`, `langchain-aws`, `boto3`

## Environment Variables (set by Terraform)

| Variable | Value |
|---|---|
| `OUTPUT_BUCKET` | S3 output bucket name |
| `BEDROCK_MODEL_ID` | `anthropic.claude-3-5-haiku-20241022-v1:0` |
| `AWS_REGION` | `us-east-1` |
| `LOG_GROUP` | CloudWatch log group name |
