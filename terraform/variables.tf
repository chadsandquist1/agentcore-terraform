variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "prefix" {
  description = "Resource name prefix used for all named resources"
  type        = string
  default     = "mojodojo-receipt-classifier"
}

variable "bedrock_model_id" {
  description = "Bedrock model ID for receipt classification"
  type        = string
  default     = "anthropic.claude-3-5-haiku-20241022-v1:0"
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 30
}
