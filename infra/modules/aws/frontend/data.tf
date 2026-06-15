data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "frontend_bucket_policy" {
  statement {
    sid       = "AllowPublicRead"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.frontend.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }

  statement {
    sid       = "AllowDeployList"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.frontend.arn]

    principals {
      type        = "AWS"
      identifiers = [var.deploy_role_arn]
    }
  }

  statement {
    sid = "AllowDeployWrite"
    actions = [
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:PutObject",
    ]
    resources = ["${aws_s3_bucket.frontend.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [var.deploy_role_arn]
    }
  }
}
