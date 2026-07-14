# Stores raw user interaction events (views, purchases, clicks)
resource "aws_dynamodb_table" "user_events" {
  name         = "${var.project_name}-user-events-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "userId"
  range_key    = "eventId"

  attribute {
    name = "userId"
    type = "S"
  }

  attribute {
    name = "eventId"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# Stores precomputed recommendation results, refreshed nightly by the
# recompute Lambda. Reading from this table at request time keeps the
# recommend Lambda's p99 latency low (single-digit-ms DynamoDB GetItem).
resource "aws_dynamodb_table" "recommendation_cache" {
  name         = "${var.project_name}-recommendation-cache-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "userId"

  attribute {
    name = "userId"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# Product catalog metadata used for content-based similarity scoring
resource "aws_dynamodb_table" "product_catalog" {
  name         = "${var.project_name}-product-catalog-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "productId"

  attribute {
    name = "productId"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}
