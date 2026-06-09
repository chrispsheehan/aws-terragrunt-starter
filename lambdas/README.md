# `lambdas`

Lambda source directories for this boilerplate.

## Structure

- `migrations/` is the fixed Lambda source directory used by CI
- `appspec-lambda.yml` is the Lambda CodeDeploy AppSpec template rendered by deploy workflows
- the generated `lambdas/build` directory is build output only and is intentionally excluded from Lambda discovery
- the deployable Lambda also needs `infra/live/<environment>/aws/migrations`

## Common Shape

- `<lambda_name>/lambda_handler.py`
- `<lambda_name>/requirements.txt`
- optional `<lambda_name>/README.md` for the Lambda's application logic and operational notes

## Build Behavior

- CI builds `lambdas/migrations` directly
- the zip artifact is published as `lambdas/<version>/migrations.zip`
- deploy workflows roll the artifact out to `infra/live/<environment>/aws/migrations`
- the migrations Lambda is invoked after CodeDeploy completes
- the Lambda build flow installs `requirements.txt` into a per-Lambda build directory
- it copies Python source files into the zip artifact
- markdown files in Lambda source trees are documentation only and are pruned before the zip artifact is created
- deploy workflows render `appspec-lambda.yml` to `appspec-lambda.rendered.yml` before uploading the AppSpec bundle

## Boilerplate Patterns

- the `migrations` Lambda shape is currently a minimal smoke target

## Logging

- logs are written to stdout so they appear in the function's CloudWatch log group

## Runtime Documentation

- add a `README.md` inside a concrete Lambda directory when the function has non-trivial business logic
- use that README to explain what the Lambda does, the event shape it expects, important downstream integrations, and any operational or failure-mode notes

## Related Docs

- migrations deployment rules: [infra/modules/aws/migrations/README.md](../infra/modules/aws/migrations/README.md)
- shared infra context: [README.md](../README.md)
