resource "aws_s3_object" "agent_zip" {
  bucket = aws_s3_bucket.agent_code.id
  key    = "agent.zip"
  source = "${path.module}/../build/agent.zip"
  etag   = filemd5("${path.module}/../build/agent.zip")

  depends_on = [aws_s3_bucket_versioning.agent_code]
}

# AgentCore Runtime disabled — keeping S3 zip upload active for when it's re-enabled.
# Uncomment to restore the hosted execution path.
#
# resource "aws_bedrockagentcore_agent_runtime" "receipt_classifier" {
#   agent_runtime_name = "receipt-classifier"
#   description        = "Receipt classification agent — deployed idle, invocable via POST /invocations"
#   role_arn           = aws_iam_role.agentcore.arn
#
#   agent_runtime_artifact {
#     code_configuration {
#       entry_point = ["agent.py"]
#       runtime     = "PYTHON_3_12"
#
#       code {
#         s3 {
#           bucket     = aws_s3_bucket.agent_code.bucket
#           prefix     = aws_s3_object.agent_zip.key
#           version_id = aws_s3_object.agent_zip.version_id
#         }
#       }
#     }
#   }
#
#   environment_variables = {
#     BEDROCK_MODEL_ID = var.bedrock_model_id
#   }
#
#   network_configuration {
#     network_mode = "PUBLIC"
#   }
# }
