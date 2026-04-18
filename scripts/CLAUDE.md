# scripts/

One-time setup scripts. Run these before `terraform init`.

## bootstrap_state.sh

Creates the Terraform remote state backend. Run **once** per AWS account/region — idempotent
(safe to re-run, will skip resources that already exist).

Creates:
- S3 bucket: `mojodojo-receipt-classifier-tfstate` (versioning enabled, AES256 encryption)
- DynamoDB table: `mojodojo-receipt-classifier-tfstate-lock` (PAY_PER_REQUEST billing, `LockID` partition key)

```bash
chmod +x scripts/bootstrap_state.sh && ./scripts/bootstrap_state.sh
```

**Must be run before `terraform init`** — Terraform cannot initialize the S3 backend if the bucket
doesn't exist yet. Terraform cannot manage these resources because they're the backend itself.

## Region

Always targets `us-east-1`. If you change regions, update this script and `terraform/backend.tf`.
