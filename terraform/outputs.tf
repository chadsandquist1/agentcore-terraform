output "input_bucket_name" {
  description = "S3 bucket for JPG uploads (pipeline trigger)"
  value       = aws_s3_bucket.input.bucket
}

output "output_bucket_name" {
  description = "S3 bucket for classification result JSON files"
  value       = aws_s3_bucket.output.bucket
}

output "agent_code_bucket_name" {
  description = "S3 bucket holding the AgentCore Runtime zip"
  value       = aws_s3_bucket.agent_code.bucket
}

output "lambda_function_arn" {
  description = "ARN of the receipt classifier Lambda function"
  value       = aws_lambda_function.processor.arn
}


output "cloudwatch_log_group" {
  description = "CloudWatch log group for Lambda classification events"
  value       = aws_cloudwatch_log_group.lambda.name
}

output "api_url" {
  description = "API Gateway base URL"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "cognito_client_id" {
  description = "Cognito User Pool Client ID for the receipt classifier"
  value       = aws_cognito_user_pool_client.receipt_classifier.id
}

output "cloudfront_url" {
  description = "CloudFront HTTPS URL for the frontend"
  value       = "https://${aws_cloudfront_distribution.frontend.domain_name}"
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID (for cache invalidation)"
  value       = aws_cloudfront_distribution.frontend.id
}

output "frontend_bucket" {
  description = "S3 bucket for frontend assets"
  value       = aws_s3_bucket.frontend.bucket
}
