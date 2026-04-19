#!/usr/bin/env bash
# One-time bootstrap: creates the Terraform remote state backend.
# Everything else (OIDC provider, GitHub Actions role, all app resources)
# is managed by Terraform itself.
set -euo pipefail

REGION="us-east-1"
STATE_BUCKET="mojodojo-receipt-classifier-tfstate"
LOCK_TABLE="mojodojo-receipt-classifier-tfstate-lock"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "Bootstrapping Terraform state backend in ${REGION}..."
echo "Account: ${ACCOUNT_ID}"
echo ""

###############################################################################
# S3 state bucket
###############################################################################
if aws s3api head-bucket --bucket "${STATE_BUCKET}" 2>/dev/null; then
  echo "  S3 bucket '${STATE_BUCKET}' already exists — skipping"
else
  aws s3api create-bucket \
    --bucket "${STATE_BUCKET}" \
    --region "${REGION}"

  aws s3api put-bucket-versioning \
    --bucket "${STATE_BUCKET}" \
    --versioning-configuration Status=Enabled

  aws s3api put-bucket-encryption \
    --bucket "${STATE_BUCKET}" \
    --server-side-encryption-configuration '{
      "Rules": [{
        "ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"},
        "BucketKeyEnabled": true
      }]
    }'

  aws s3api put-public-access-block \
    --bucket "${STATE_BUCKET}" \
    --public-access-block-configuration \
      BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

  echo "  Created S3 bucket '${STATE_BUCKET}'"
fi

###############################################################################
# DynamoDB lock table
###############################################################################
if aws dynamodb describe-table --table-name "${LOCK_TABLE}" --region "${REGION}" 2>/dev/null; then
  echo "  DynamoDB table '${LOCK_TABLE}' already exists — skipping"
else
  aws dynamodb create-table \
    --table-name "${LOCK_TABLE}" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "${REGION}"

  echo "  Created DynamoDB table '${LOCK_TABLE}'"
fi

echo ""
echo "Bootstrap complete."
echo ""
echo "Next steps:"
echo "  cd terraform && terraform init"
echo "  terraform import aws_iam_openid_connect_provider.github_actions arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
echo "  terraform import aws_iam_role.github_actions mojodojo-receipt-classifier-github-actions"
echo "  terraform import aws_iam_role_policy.github_actions mojodojo-receipt-classifier-github-actions:mojodojo-receipt-classifier-github-actions-policy"
echo "  terraform apply"
