resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts-${var.environment}"
}

resource "aws_sns_topic_subscription" "alerts_email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

locals {
  alarm_lambdas = {
    ingest     = aws_lambda_function.ingest.function_name
    recompute  = aws_lambda_function.recompute.function_name
    recommend  = aws_lambda_function.recommend.function_name
    authorizer = aws_lambda_function.authorizer.function_name
  }
}

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  for_each = local.alarm_lambdas

  alarm_name          = "${var.project_name}-${each.key}-errors-${var.environment}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = each.value
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "api_gateway_5xx" {
  alarm_name          = "${var.project_name}-api-5xx-${var.environment}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "5xx"
  namespace           = "AWS/ApiGateway"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiId = aws_apigatewayv2_api.smartpicks_api.id
    Stage = aws_apigatewayv2_stage.default.name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}
