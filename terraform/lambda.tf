data "archive_file" "lambda_function" {
  type        = "zip"
  output_path = "${path.module}/../build/lambda_function.zip"

  source {
    content  = file("${path.module}/../lambda/handler.py")
    filename = "handler.py"
  }

  source {
    content  = file("${path.module}/../lambda/classifications.json")
    filename = "classifications.json"
  }
}

resource "aws_s3_object" "lambda_layer" {
  bucket = aws_s3_bucket.agent_code.id
  key    = "lambda_layer.zip"
  source = "${path.module}/../build/lambda_layer.zip"
  etag   = filemd5("${path.module}/../build/lambda_layer.zip")

  depends_on = [aws_s3_bucket_versioning.agent_code]
}

resource "aws_lambda_layer_version" "langchain" {
  layer_name               = "${var.prefix}-langchain"
  s3_bucket                = aws_s3_bucket.agent_code.bucket
  s3_key                   = aws_s3_object.lambda_layer.key
  s3_object_version        = aws_s3_object.lambda_layer.version_id
  compatible_runtimes      = ["python3.12"]
  compatible_architectures = ["x86_64"]
}

resource "aws_lambda_function" "processor" {
  function_name    = "receipt-classifier-processor"
  role             = aws_iam_role.lambda.arn
  handler          = "handler.handler"
  runtime          = "python3.12"
  architectures    = ["x86_64"]
  filename         = data.archive_file.lambda_function.output_path
  source_code_hash = data.archive_file.lambda_function.output_base64sha256
  timeout          = 60
  memory_size      = 512
  layers           = [aws_lambda_layer_version.langchain.arn]

  environment {
    variables = {
      OUTPUT_BUCKET    = aws_s3_bucket.output.bucket
      BEDROCK_MODEL_ID = var.bedrock_model_id
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda]
}

resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.input.arn
}

resource "aws_s3_bucket_notification" "input_trigger" {
  bucket = aws_s3_bucket.input.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.processor.arn
    events              = ["s3:ObjectCreated:Put"]
    filter_suffix       = ".jpg"
  }

  depends_on = [aws_lambda_permission.allow_s3]
}
