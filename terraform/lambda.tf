data "archive_file" "ingest_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/ingest"
  output_path = "${path.module}/../build/ingest.zip"
}

data "archive_file" "recompute_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/recompute"
  output_path = "${path.module}/../build/recompute.zip"
}

data "archive_file" "recommend_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/recommend"
  output_path = "${path.module}/../build/recommend.zip"
}

resource "aws_lambda_function" "ingest" {
  function_name    = "${var.project_name}-ingest-${var.environment}"
  filename         = data.archive_file.ingest_zip.output_path
  source_code_hash = data.archive_file.ingest_zip.output_base64sha256
  handler          = "handler.handler"
  runtime          = "python3.12"
  role             = var.lab_role_arn
  timeout          = 10
  memory_size      = 256

  environment {
    variables = {
      USER_EVENTS_TABLE    = aws_dynamodb_table.user_events.name
      EVENT_ARCHIVE_BUCKET = aws_s3_bucket.event_archive.bucket
    }
  }
}

resource "aws_lambda_function" "recompute" {
  function_name    = "${var.project_name}-recompute-${var.environment}"
  filename         = data.archive_file.recompute_zip.output_path
  source_code_hash = data.archive_file.recompute_zip.output_base64sha256
  handler          = "handler.handler"
  runtime          = "python3.12"
  role             = var.lab_role_arn
  timeout          = 60
  memory_size      = 512

  environment {
    variables = {
      USER_EVENTS_TABLE          = aws_dynamodb_table.user_events.name
      RECOMMENDATION_CACHE_TABLE = aws_dynamodb_table.recommendation_cache.name
      PRODUCT_CATALOG_TABLE      = aws_dynamodb_table.product_catalog.name
    }
  }
}

resource "aws_lambda_function" "recommend" {
  function_name    = "${var.project_name}-recommend-${var.environment}"
  filename         = data.archive_file.recommend_zip.output_path
  source_code_hash = data.archive_file.recommend_zip.output_base64sha256
  handler          = "handler.handler"
  runtime          = "python3.12"
  role             = var.lab_role_arn
  timeout          = 10
  memory_size      = 256

  environment {
    variables = {
      RECOMMENDATION_CACHE_TABLE = aws_dynamodb_table.recommendation_cache.name
    }
  }
}

resource "aws_cloudwatch_log_group" "ingest_logs" {
  name              = "/aws/lambda/${aws_lambda_function.ingest.function_name}"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "recompute_logs" {
  name              = "/aws/lambda/${aws_lambda_function.recompute.function_name}"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "recommend_logs" {
  name              = "/aws/lambda/${aws_lambda_function.recommend.function_name}"
  retention_in_days = 14
}
