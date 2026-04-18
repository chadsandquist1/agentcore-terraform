resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/receipt-classifier-processor"
  retention_in_days = var.log_retention_days
}
