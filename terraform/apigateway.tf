###############################################################################
# API Lambda
###############################################################################

resource "aws_lambda_function" "api" {
  function_name = "${var.prefix}-api"
  filename      = "${path.module}/../build/api_handler.zip"
  source_code_hash = filemd5("${path.module}/../build/api_handler.zip")
  handler       = "api_handler.handler"
  runtime       = "python3.12"
  role          = aws_iam_role.api_lambda.arn
  timeout       = 30

  environment {
    variables = {
      INPUT_BUCKET  = aws_s3_bucket.input.bucket
      OUTPUT_BUCKET = aws_s3_bucket.output.bucket
    }
  }
}

resource "aws_cloudwatch_log_group" "api_lambda" {
  name              = "/aws/lambda/${aws_lambda_function.api.function_name}"
  retention_in_days = var.log_retention_days
}

###############################################################################
# HTTP API Gateway
###############################################################################

resource "aws_apigatewayv2_api" "receipt" {
  name          = "${var.prefix}-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["content-type", "authorization"]
    max_age       = 300
  }
}

resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id           = aws_apigatewayv2_api.receipt.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "cognito"

  jwt_configuration {
    audience = [aws_cognito_user_pool_client.receipt_classifier.id]
    issuer   = "https://cognito-idp.${var.aws_region}.amazonaws.com/${data.aws_cognito_user_pool.shared.id}"
  }
}

resource "aws_apigatewayv2_integration" "api" {
  api_id                 = aws_apigatewayv2_api.receipt.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "presign" {
  api_id             = aws_apigatewayv2_api.receipt.id
  route_key          = "POST /presign"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
  target             = "integrations/${aws_apigatewayv2_integration.api.id}"
}

resource "aws_apigatewayv2_route" "results" {
  api_id             = aws_apigatewayv2_api.receipt.id
  route_key          = "GET /results/{key+}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
  target             = "integrations/${aws_apigatewayv2_integration.api.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.receipt.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.receipt.execution_arn}/*/*"
}
