locals {
  lambda_runtime         = "python3.12"
  lambda_handler         = "lambda_handler.lambda_handler"
  compute_platform       = "Lambda"
  lambda_name            = "${var.environment}-${var.project_name}-migrations"
  deployment_config_name = "${local.lambda_name}-deploy-allatonce"
}
