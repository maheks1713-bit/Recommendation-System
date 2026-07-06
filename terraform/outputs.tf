output "api_endpoint" {
  description = "Base URL of the deployed HTTP API"
  value       = aws_apigatewayv2_api.smartpicks_api.api_endpoint
}

output "user_events_table" {
  value = aws_dynamodb_table.user_events.name
}

output "recommendation_cache_table" {
  value = aws_dynamodb_table.recommendation_cache.name
}

output "product_catalog_table" {
  value = aws_dynamodb_table.product_catalog.name
}

output "event_archive_bucket" {
  value = aws_s3_bucket.event_archive.bucket
}
