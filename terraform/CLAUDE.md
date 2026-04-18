# terraform/

All infrastructure as code. Manages every AWS resource for the receipt classifier pipeline.

## Provider Requirements

- **Terraform >= 1.0**
- **AWS provider >= 6.22.0** — required for `code_configuration` (S3 zip) in `aws_bedrockagentcore_agent_runtime`; earlier versions require ECR

## Critical Rules

- **No `null_resource`** — use `terraform_data` for any provisioner blocks
- **No VPC** — all services use public endpoints
- **No ECR** — AgentCore Runtime deployed via S3 zip (`code_configuration` block)
- **Build artifacts must exist before `terraform plan`** — `filemd5()` evaluates at plan time;
  run `make build` from repo root first

## Bucket Naming

All S3 buckets use the pattern `mojodojo-receipt-classifier-<aws_account_id>-<purpose>`:
- `-input` — receives JPG uploads, triggers Lambda
- `-output` — receives classification result JSON
- `-agent-code` — stores `build/agent.zip` for AgentCore Runtime

Account ID is sourced via `data "aws_caller_identity" "current"` — never hardcoded.

## State Backend

Remote state stored in S3. Bootstrap with `../scripts/bootstrap_state.sh` before `terraform init`.

| Resource | Name |
|---|---|
| S3 bucket | `mojodojo-receipt-classifier-tfstate` |
| DynamoDB table | `mojodojo-receipt-classifier-tfstate-lock` |

## File Map

| File | Manages |
|---|---|
| `backend.tf` | S3 state bucket + DynamoDB lock table |
| `main.tf` | Provider config, `aws_caller_identity` data source |
| `variables.tf` | Input variables (region, prefix) |
| `s3.tf` | Input bucket, output bucket, agent-code bucket |
| `lambda.tf` | Lambda function (x86_64), LangChain layer, S3 event trigger |
| `agentcore.tf` | `aws_bedrockagentcore_agent_runtime` (S3 zip, ARM64) |
| `iam.tf` | Lambda execution role + AgentCore execution role (least-privilege) |
| `cloudwatch.tf` | Log group `/aws/lambda/receipt-classifier-processor`, retention policy |
| `outputs.tf` | Bucket names, Lambda ARN, AgentCore runtime ARN |

## IAM Least-Privilege Summary

**Lambda role** needs:
- `s3:GetObject` on input bucket
- `s3:PutObject` on output bucket
- `textract:DetectDocumentText`
- `bedrock:InvokeModel` for `anthropic.claude-3-5-haiku-20241022-v1:0`
- `logs:CreateLogGroup`, `logs:CreateLogStream`, `logs:PutLogEvents`

**AgentCore role** needs:
- `s3:GetObject` on agent-code bucket
- `bedrock:InvokeModel` for `anthropic.claude-3-5-haiku-20241022-v1:0`
- `textract:DetectDocumentText`

## Common Commands

```bash
cd terraform
terraform init
terraform plan
terraform apply
terraform destroy
```
