resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Durable, cheap, append-only archive of every raw event. DynamoDB holds only
# the current working set; S3 is the long-term source of truth used for
# reprocessing/audit and satisfies the "second storage type" requirement.
resource "aws_s3_bucket" "event_archive" {
  bucket = "${var.project_name}-event-archive-${random_id.bucket_suffix.hex}"

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "event_archive_versioning" {
  bucket = aws_s3_bucket.event_archive.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "event_archive_block" {
  bucket                  = aws_s3_bucket.event_archive.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "event_archive_sse" {
  bucket = aws_s3_bucket.event_archive.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_policy" "event_archive_tls_only" {
  bucket = aws_s3_bucket.event_archive.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.event_archive.arn,
          "${aws_s3_bucket.event_archive.arn}/*",
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_lifecycle_configuration" "event_archive_lifecycle" {
  bucket = aws_s3_bucket.event_archive.id
  rule {
    id     = "expire-old-raw-events"
    status = "Enabled"
    filter {
      prefix = "raw-events/"
    }
    expiration {
      days = 90
    }
  }
}
