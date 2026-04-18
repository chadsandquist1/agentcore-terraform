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

output "agentcore_runtime_arn" {
  description = "ARN of the AgentCore Runtime (deployed idle)"
  value       = aws_bedrockagentcore_agent_runtime.receipt_classifier.agent_runtime_arn
}

output "agentcore_runtime_id" {
  description = "ID of the AgentCore Runtime"
  value       = aws_bedrockagentcore_agent_runtime.receipt_classifier.agent_runtime_id
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group for Lambda classification events"
  value       = aws_cloudwatch_log_group.lambda.name
}
