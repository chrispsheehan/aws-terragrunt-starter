# `migrations`

Concrete Lambda module for the repo's minimal deployable Lambda surface.

## Owns

- Lambda function and alias
- Lambda CloudWatch log group
- all-at-once Lambda CodeDeploy application, deployment group, and deployment config
- IAM roles and policies needed by the Lambda and CodeDeploy

The shared bootstrap Lambda zip now lives in `_shared/code_bucket`; this module
consumes the uploaded object key and keeps the stable Lambda deployment surface
for code deploy.

## Key Outputs

- `lambda_function_name`
- `lambda_alias_name`
- `cloudwatch_log_group`

The current Lambda handler is an MVP smoke target from `lambdas/migrations`.
The module keeps the stable Lambda deployment surface so the code deploy
workflow can publish a new version and roll it out through CodeDeploy.

The live Terragrunt stack passes the runtime security group id from `security`
as an explicit input. For bootstrap-friendly plan and validate flows, keep
Terragrunt dependency mocks in the live stack rather than reading sibling state
inside this module.
