# agent/

AgentCore Runtime — alternate hosted execution path. Deployed and idle (no active trigger).

## What This Is

`agent.py` is a FastAPI HTTP server that satisfies the AgentCore Runtime contract:
- `POST /invocations` — receives a classification request, runs the LangChain agent, returns JSON result
- `GET /health` — returns 200 OK; AWS polls this to confirm the process is alive

AgentCore Runtime is **session-scoped**, not always-on. AWS spins up a microVM per invocation session,
starts this server, handles the request, then tears it down. Cost is ~$0 when idle.

## Architecture

- **ARM64 / Graviton** — cross-compiled deps required (see below)
- **Port 8080** — hardcoded by AgentCore contract; do not change
- **Same agent logic as `lambda/handler.py`** — Textract + Claude Haiku via LangChain

## Critical Rules

- **ARM64 deps** — MUST install with `--platform aarch64-manylinux2014 --only-binary=:all:`
  Standard `pip install` produces x86 wheels that fail silently on Graviton at runtime
- **No VPC** — AgentCore Runtime uses public endpoints; do not add VPC config
- **Always read categories from `../lambda/classifications.json`** — single source of truth

## Files

| File | Purpose |
|---|---|
| `agent.py` | FastAPI server — `POST /invocations`, `GET /health` |
| `requirements.txt` | Deps cross-compiled for ARM64 |

## Dependencies (requirements.txt)

Installed with:
```
pip install --platform aarch64-manylinux2014 --only-binary=:all: --target ./build -r requirements.txt
```

Key packages: `langchain`, `langchain-aws`, `fastapi`, `uvicorn`, `boto3`

## Startup Command (AgentCore invokes this)

```
uvicorn agent:app --host 0.0.0.0 --port 8080
```

## Request / Response Shape

POST /invocations body:
```json
{"image_key": "uploads/receipt.jpg", "bucket": "mojodojo-receipt-classifier-<account_id>-input"}
```

Response:
```json
{"category": "Food", "confidence": "high", "raw_text": "..."}
```
