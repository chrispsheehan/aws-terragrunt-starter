locals {
  name        = "${var.environment}-${var.project_name}"
  bucket_name = "${data.aws_caller_identity.current.account_id}-${local.name}"
  root_file   = "index.html"
}
