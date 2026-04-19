# Receipt Classifier

Serverless AWS pipeline that classifies receipt images via OCR. JPG uploaded to S3 → Lambda (LangChain + Textract) → Claude Haiku → classification result written to S3 + CloudWatch.

## Tech Stack

- **Python 3.12** — Lambda + AgentCore agent
- **LangChain / langchain-aws** — agent orchestration, tool calling
- **AWS Textract** — OCR (synchronous, single-page JPG only)
- **Bedrock** — `anthropic.claude-haiku-4-5-20251001-v1:0`
- **AgentCore Runtime** — alternate hosted execution path (ARM64/Graviton)
- **Terraform >= 1.0, AWS provider >= 6.22.0** — all infra as code
- **GitHub Actions** — CI/CD (build artifacts → terraform apply)

## Infrastructure Rule

**All AWS resource changes must go through Terraform.** Never use one-off AWS CLI commands or scripts to create or update resources. The only exception is `scripts/bootstrap_state.sh`, which creates the S3 state bucket and DynamoDB lock table — the two resources that must exist before Terraform can initialize. Everything else, including the GitHub Actions OIDC provider, role, and policy, is managed in `terraform/github_actions.tf`.

## Commands

```bash
# First-time setup (run once before terraform init — creates S3 state + DynamoDB only)
chmod +x scripts/bootstrap_state.sh && ./scripts/bootstrap_state.sh

# Build Lambda layer (x86_64) + AgentCore zip (ARM64) — required before terraform
make build

# Terraform
cd terraform && terraform init
cd terraform && terraform plan
cd terraform && terraform apply
cd terraform && terraform destroy

# Test
make test-upload FILE=my_receipt.jpg

# Tail logs
aws logs tail /aws/lambda/receipt-classifier-processor --follow --format short
```

## Project Structure

```
receipt-classifier/
├── lambda/
│   ├── handler.py              # LangChain agent — Textract tool + Bedrock classification
│   ├── classifications.json    # Source of truth for receipt categories
│   └── requirements.txt
├── agent/
│   ├── agent.py                # AgentCore Runtime — FastAPI server, same agent logic
│   └── requirements.txt
├── terraform/
│   ├── agentcore.tf            # aws_bedrockagentcore_agent_runtime (S3 zip, no ECR)
│   ├── backend.tf              # S3 state + DynamoDB lock
│   ├── cloudwatch.tf
│   ├── iam.tf                  # Lambda role + AgentCore role (least-privilege)
│   ├── lambda.tf               # Function, LangChain layer, S3 trigger
│   ├── main.tf                 # Provider config
│   ├── outputs.tf
│   ├── s3.tf                   # input / output / agent-code buckets
│   └── variables.tf
├── scripts/
│   └── bootstrap_state.sh      # One-time state backend creation
└── Makefile                    # Cross-compiles Python deps for x86 + ARM64
```

## Architecture

```
S3 input (JPG)  →  Lambda (LangChain agent, x86_64)
                       ├─ Tool: extract_text_with_textract  →  Textract
                       └─ Claude Haiku (Bedrock)  →  classification JSON
                       │
                       ├──▶  S3 output  results/<key>_<timestamp>.json
                       └──▶  CloudWatch  {"event":"RECEIPT_CLASSIFICATION", ...}

AgentCore Runtime (ARM64)  ←  POST /invocations  ←  optional alternate path
    └─ agent/agent.py — same LangChain logic as FastAPI HTTP server
```

## Receipt Categories

Defined in `lambda/classifications.json` — always read from this file, never hardcode categories in code.

| Category | Matches |
|---|---|
| Food | Restaurants, groceries, cafes, delivery |
| Shoes | Footwear, sneakers, boots |
| Clothes | Apparel, fashion retail |
| Household | Hardware, furniture, appliances, cleaning |
| Liquor | Alcohol, wine, beer, bar tabs |
| Mix | Multiple categories on one receipt |
| Other | Valid receipt, no matching category |
| Not Receipt | Not a receipt image |

## Critical Constraints

> **Violating these will silently break the deployment.**

- **ARM64 deps for AgentCore**: `agent/requirements.txt` MUST be installed with `--platform aarch64-manylinux2014 --only-binary=:all:`. Standard `pip install` produces x86 wheels that fail silently on Graviton at runtime.
- **x86_64 deps for Lambda**: Lambda layer uses `--platform manylinux2014_x86_64`.
- **AWS provider >= 6.22.0**: Required for `code_configuration` (S3 zip) in `aws_bedrockagentcore_agent_runtime`. Earlier versions require ECR.
- **No `null_resource`**: Use `terraform_data` for any Terraform provisioner blocks.
- **No VPC**: All services use public endpoints. Do not add VPC config.
- **JPG only**: Lambda skips and logs non-JPG uploads. Textract runs synchronously — do not switch to async API (requires SNS/SQS).
- **Separate input/output buckets**: Never merge them — S3 notification on the output bucket would cause an infinite trigger loop.

## Key Decisions

**Why `make build` before `terraform apply`?**
Terraform references pre-built zips (`build/lambda_layer.zip`, `build/agent.zip`). `filemd5()` evaluates at plan time so the zips must already exist. The Makefile handles cross-compilation; CI runs `make build` as a dedicated job before Terraform.

**Why FastAPI in the AgentCore Runtime?**
AgentCore expects an HTTP server on port 8080 with `POST /invocations` and `GET /health`. FastAPI is the lightest option without the official SDK.

**Why no `terraform_data` build step inside Terraform?**
Keeps Terraform state clean and separates build concerns from infrastructure state. Build artifacts are the Makefile/CI's responsibility.

## Prerequisites (First Run Only)

1. `./scripts/bootstrap_state.sh` — creates S3 state bucket + DynamoDB lock table
2. AWS console (us-east-1) → Bedrock → enable model access for `anthropic.claude-haiku-4-5-20251001-v1:0`
3. GitHub → Settings → Secrets: add `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`
4. `make build` — cross-compile and package all deployment artifacts
