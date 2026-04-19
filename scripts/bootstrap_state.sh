#!/usr/bin/env bash
set -euo pipefail

REGION="us-east-1"
STATE_BUCKET="mojodojo-receipt-classifier-tfstate"
LOCK_TABLE="mojodojo-receipt-classifier-tfstate-lock"
GITHUB_REPO="chadsandquist1/agentcore-terraform"
OIDC_URL="https://token.actions.githubusercontent.com"
OIDC_THUMBPRINT="6938fd4d98bab03faadb97b34396831e3780aea1"
ROLE_NAME="mojodojo-receipt-classifier-github-actions"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "Bootstrapping Terraform state backend and GitHub OIDC in ${REGION}..."
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

###############################################################################
# GitHub Actions OIDC identity provider
###############################################################################
OIDC_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"

if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "${OIDC_ARN}" 2>/dev/null; then
  echo "  OIDC provider already exists — skipping"
else
  aws iam create-open-id-connect-provider \
    --url "${OIDC_URL}" \
    --client-id-list "sts.amazonaws.com" \
    --thumbprint-list "${OIDC_THUMBPRINT}"

  echo "  Created OIDC provider for token.actions.githubusercontent.com"
fi

###############################################################################
# GitHub Actions IAM role
###############################################################################
TRUST_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "${OIDC_ARN}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:${GITHUB_REPO}:*"
        }
      }
    }
  ]
}
EOF
)

PERMISSIONS_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3State",
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"],
      "Resource": [
        "arn:aws:s3:::${STATE_BUCKET}",
        "arn:aws:s3:::${STATE_BUCKET}/*"
      ]
    },
    {
      "Sid": "DynamoDBLock",
      "Effect": "Allow",
      "Action": ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"],
      "Resource": "arn:aws:dynamodb:${REGION}:${ACCOUNT_ID}:table/${LOCK_TABLE}"
    },
    {
      "Sid": "S3Resources",
      "Effect": "Allow",
      "Action": ["s3:*"],
      "Resource": [
        "arn:aws:s3:::mojodojo-receipt-classifier-${ACCOUNT_ID}-*",
        "arn:aws:s3:::mojodojo-receipt-classifier-${ACCOUNT_ID}-*/*"
      ]
    },
    {
      "Sid": "Lambda",
      "Effect": "Allow",
      "Action": ["lambda:*"],
      "Resource": "arn:aws:lambda:${REGION}:${ACCOUNT_ID}:function:receipt-classifier-*"
    },
    {
      "Sid": "LambdaLayer",
      "Effect": "Allow",
      "Action": ["lambda:PublishLayerVersion", "lambda:GetLayerVersion", "lambda:DeleteLayerVersion"],
      "Resource": "arn:aws:lambda:${REGION}:${ACCOUNT_ID}:layer:mojodojo-receipt-classifier-*"
    },
    {
      "Sid": "IAM",
      "Effect": "Allow",
      "Action": ["iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:PutRolePolicy",
                 "iam:DeleteRolePolicy", "iam:GetRolePolicy", "iam:PassRole",
                 "iam:ListRolePolicies", "iam:ListAttachedRolePolicies",
                 "iam:TagRole", "iam:UntagRole", "iam:ListInstanceProfilesForRole"],
      "Resource": "arn:aws:iam::${ACCOUNT_ID}:role/mojodojo-receipt-classifier-*"
    },
    {
      "Sid": "CloudWatchDescribe",
      "Effect": "Allow",
      "Action": ["logs:DescribeLogGroups"],
      "Resource": "arn:aws:logs:${REGION}:${ACCOUNT_ID}:*"
    },
    {
      "Sid": "CloudWatch",
      "Effect": "Allow",
      "Action": ["logs:CreateLogGroup", "logs:DeleteLogGroup", "logs:PutRetentionPolicy",
                 "logs:ListTagsLogGroup", "logs:TagLogGroup",
                 "logs:UntagLogGroup", "logs:ListTagsForResource", "logs:TagResource",
                 "logs:UntagResource"],
      "Resource": "arn:aws:logs:${REGION}:${ACCOUNT_ID}:log-group:/aws/lambda/receipt-classifier-*"
    },
    {
      "Sid": "BedrockAgentCore",
      "Effect": "Allow",
      "Action": ["bedrock-agentcore:*"],
      "Resource": "*"
    },
    {
      "Sid": "CloudFront",
      "Effect": "Allow",
      "Action": [
        "cloudfront:CreateDistribution", "cloudfront:DeleteDistribution",
        "cloudfront:GetDistribution", "cloudfront:UpdateDistribution",
        "cloudfront:TagResource", "cloudfront:ListTagsForResource",
        "cloudfront:CreateInvalidation", "cloudfront:GetInvalidation",
        "cloudfront:CreateOriginAccessControl", "cloudfront:DeleteOriginAccessControl",
        "cloudfront:GetOriginAccessControl", "cloudfront:UpdateOriginAccessControl",
        "cloudfront:ListOriginAccessControls"
      ],
      "Resource": "*"
    },
    {
      "Sid": "Cognito",
      "Effect": "Allow",
      "Action": [
        "cognito-idp:CreateUserPoolClient", "cognito-idp:DeleteUserPoolClient",
        "cognito-idp:DescribeUserPoolClient", "cognito-idp:UpdateUserPoolClient",
        "cognito-idp:DescribeUserPool", "cognito-idp:ListUserPoolClients"
      ],
      "Resource": "arn:aws:cognito-idp:${REGION}:${ACCOUNT_ID}:userpool/*"
    },
    {
      "Sid": "ApiGateway",
      "Effect": "Allow",
      "Action": ["apigateway:*"],
      "Resource": "arn:aws:apigateway:${REGION}::/*"
    }
  ]
}
EOF
)

if aws iam get-role --role-name "${ROLE_NAME}" 2>/dev/null; then
  echo "  IAM role '${ROLE_NAME}' already exists — updating policy"
else
  aws iam create-role \
    --role-name "${ROLE_NAME}" \
    --assume-role-policy-document "${TRUST_POLICY}"
  echo "  Created IAM role '${ROLE_NAME}'"
fi

aws iam put-role-policy \
  --role-name "${ROLE_NAME}" \
  --policy-name "${ROLE_NAME}-policy" \
  --policy-document "${PERMISSIONS_POLICY}"
echo "  Applied permissions policy to '${ROLE_NAME}'"

ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"

echo ""
echo "Bootstrap complete."
echo ""
echo "GitHub Actions role ARN (add as GH secret AWS_ROLE_ARN):"
echo "  ${ROLE_ARN}"
echo ""
echo "Next steps:"
echo "  1. Add secret AWS_ROLE_ARN=${ROLE_ARN} to GitHub repo settings"
echo "  2. cd terraform && terraform init"
