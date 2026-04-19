###############################################################################
# GitHub Actions OIDC — identity provider, role, and permissions policy
###############################################################################

variable "github_repo" {
  description = "GitHub repo allowed to assume the CI role (format: owner/repo)"
  type        = string
  default     = "chadsandquist1/agentcore-terraform"
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

data "aws_iam_policy_document" "github_actions_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:*"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "${var.prefix}-github-actions"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume.json
}

data "aws_iam_policy_document" "github_actions_permissions" {
  statement {
    sid       = "STSCaller"
    effect    = "Allow"
    actions   = ["sts:GetCallerIdentity"]
    resources = ["*"]
  }

  statement {
    sid    = "S3State"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
    ]

    resources = [
      "arn:aws:s3:::${var.prefix}-tfstate",
      "arn:aws:s3:::${var.prefix}-tfstate/*",
    ]
  }

  statement {
    sid       = "DynamoDBLock"
    effect    = "Allow"
    actions   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"]
    resources = ["arn:aws:dynamodb:${var.aws_region}:${local.account_id}:table/${var.prefix}-tfstate-lock"]
  }

  statement {
    sid       = "S3Resources"
    effect    = "Allow"
    actions   = ["s3:*"]
    resources = [
      "arn:aws:s3:::${var.prefix}-${local.account_id}-*",
      "arn:aws:s3:::${var.prefix}-${local.account_id}-*/*",
    ]
  }

  statement {
    sid    = "Lambda"
    effect = "Allow"
    actions = ["lambda:*"]

    resources = [
      "arn:aws:lambda:${var.aws_region}:${local.account_id}:function:${var.prefix}-*",
    ]
  }

  statement {
    sid    = "LambdaLayer"
    effect = "Allow"

    actions = [
      "lambda:PublishLayerVersion",
      "lambda:GetLayerVersion",
      "lambda:DeleteLayerVersion",
    ]

    resources = [
      "arn:aws:lambda:${var.aws_region}:${local.account_id}:layer:${var.prefix}-*",
    ]
  }

  statement {
    sid    = "IAM"
    effect = "Allow"

    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:GetRolePolicy",
      "iam:PassRole",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:ListInstanceProfilesForRole",
      "iam:CreateOpenIDConnectProvider",
      "iam:GetOpenIDConnectProvider",
      "iam:UpdateOpenIDConnectProviderThumbprint",
      "iam:DeleteOpenIDConnectProvider",
      "iam:TagOpenIDConnectProvider",
    ]

    resources = [
      "arn:aws:iam::${local.account_id}:role/${var.prefix}-*",
      "arn:aws:iam::${local.account_id}:oidc-provider/token.actions.githubusercontent.com",
    ]
  }

  statement {
    sid       = "CloudWatchDescribe"
    effect    = "Allow"
    actions   = ["logs:DescribeLogGroups"]
    resources = ["arn:aws:logs:${var.aws_region}:${local.account_id}:*"]
  }

  statement {
    sid    = "CloudWatch"
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:DeleteLogGroup",
      "logs:PutRetentionPolicy",
      "logs:ListTagsLogGroup",
      "logs:TagLogGroup",
      "logs:UntagLogGroup",
      "logs:ListTagsForResource",
      "logs:TagResource",
      "logs:UntagResource",
    ]

    resources = [
      "arn:aws:logs:${var.aws_region}:${local.account_id}:log-group:/aws/lambda/${var.prefix}-*",
    ]
  }

  statement {
    sid       = "CloudFront"
    effect    = "Allow"

    actions = [
      "cloudfront:CreateDistribution",
      "cloudfront:DeleteDistribution",
      "cloudfront:GetDistribution",
      "cloudfront:UpdateDistribution",
      "cloudfront:TagResource",
      "cloudfront:ListTagsForResource",
      "cloudfront:CreateInvalidation",
      "cloudfront:GetInvalidation",
      "cloudfront:CreateOriginAccessControl",
      "cloudfront:DeleteOriginAccessControl",
      "cloudfront:GetOriginAccessControl",
      "cloudfront:UpdateOriginAccessControl",
      "cloudfront:ListOriginAccessControls",
    ]

    resources = ["*"]
  }

  statement {
    sid    = "Cognito"
    effect = "Allow"

    actions = [
      "cognito-idp:CreateUserPoolClient",
      "cognito-idp:DeleteUserPoolClient",
      "cognito-idp:DescribeUserPoolClient",
      "cognito-idp:UpdateUserPoolClient",
      "cognito-idp:DescribeUserPool",
      "cognito-idp:ListUserPoolClients",
    ]

    resources = ["arn:aws:cognito-idp:${var.aws_region}:${local.account_id}:userpool/*"]
  }

  statement {
    sid       = "ApiGateway"
    effect    = "Allow"
    actions   = ["apigateway:*"]
    resources = ["arn:aws:apigateway:${var.aws_region}::/*"]
  }
}

resource "aws_iam_role_policy" "github_actions" {
  name   = "${var.prefix}-github-actions-policy"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions_permissions.json
}

output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions (set as AWS_ROLE_ARN secret)"
  value       = aws_iam_role.github_actions.arn
}
