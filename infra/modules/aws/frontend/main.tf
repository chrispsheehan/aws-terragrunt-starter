resource "aws_s3_bucket" "frontend" {
  bucket        = local.bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_ownership_controls" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_website_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  index_document {
    suffix = local.root_file
  }

  error_document {
    key = local.root_file
  }
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  policy = data.aws_iam_policy_document.frontend_bucket_policy.json

  depends_on = [aws_s3_bucket_public_access_block.frontend]
}

resource "aws_s3_object" "bootstrap_index" {
  bucket       = aws_s3_bucket.frontend.id
  key          = local.root_file
  source       = "${path.module}/bootstrap/index.html"
  etag         = filemd5("${path.module}/bootstrap/index.html")
  content_type = "text/html; charset=utf-8"

  lifecycle {
    ignore_changes = [
      content_type,
      etag,
      source,
      tags_all,
    ]
  }
}
