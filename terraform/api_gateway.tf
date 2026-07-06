resource "aws_apigatewayv2_api" "smartpicks_api" {
  name          = "${var.project_name}-api-${var.environment}"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.smartpicks_api.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw_logs.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip              = "$context.identity.sourceIp"
      requestTime     = "$context.requestTime"
      httpMethod      = "$context.httpMethod"
      routeKey        = "$context.routeKey"
      status          = "$context.status"
      integrationError = "$context.integrationErrorMessage"
    })
  }
}

resource "aws_cloudwatch_log_group" "api_gw_logs" {
  name              = "/aws/apigateway/${var.project_name}-${var.environment}"
  retention_in_days = 14
}

# --- POST /events -> ingest Lambda ---
resource "aws_apigatewayv2_integration" "ingest_integration" {
  api_id                 = aws_apigatewayv2_api.smartpicks_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.ingest.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "post_events" {
  api_id    = aws_apigatewayv2_api.smartpicks_api.id
  route_key = "POST /events"
  target    = "integrations/${aws_apigatewayv2_integration.ingest_integration.id}"
}

resource "aws_lambda_permission" "allow_apigw_ingest" {
  statement_id  = "AllowAPIGatewayInvokeIngest"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ingest.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.smartpicks_api.execution_arn}/*/*"
}

# --- GET /recommendations/{userId} -> recommend Lambda ---
resource "aws_apigatewayv2_integration" "recommend_integration" {
  api_id                 = aws_apigatewayv2_api.smartpicks_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.recommend.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "get_recommendations" {
  api_id    = aws_apigatewayv2_api.smartpicks_api.id
  route_key = "GET /recommendations/{userId}"
  target    = "integrations/${aws_apigatewayv2_integration.recommend_integration.id}"
}

resource "aws_lambda_permission" "allow_apigw_recommend" {
  statement_id  = "AllowAPIGatewayInvokeRecommend"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.recommend.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.smartpicks_api.execution_arn}/*/*"
}
