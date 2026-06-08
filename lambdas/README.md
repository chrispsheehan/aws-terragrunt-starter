# `lambdas`

Lambda source directories for this boilerplate.

## Structure

- `deploy.yml` is the Lambda build/deploy manifest
- each entry in `deploy.yml` maps a Lambda source directory to a live Terragrunt stack path template
- the generated `lambdas/build` directory is build output only and is intentionally excluded from Lambda discovery
- a deployable Lambda also needs the live Terragrunt stack declared by its manifest `stack` value

## Common Shape

- `<lambda_name>/lambda_handler.py`
- `<lambda_name>/requirements.txt`
- optional `<lambda_name>/README.md` for the Lambda's application logic and operational notes

## Build Behavior

- Lambda discovery reads `lambdas/deploy.yml`
- `stack` is a repo-relative Terragrunt stack path template and must use `{environment}` for the environment segment, for example `infra/live/{environment}/aws/migrations`
- `source_dir` is the repo-relative source directory to package, for example `lambdas/migrations`
- the zip artifact name is computed from `basename(source_dir)`, so `lambdas/migrations` publishes `lambdas/<version>/migrations.zip`
- build workflows deduplicate by `source_dir`; deploy workflows keep every manifest entry so the same source can roll out to multiple Lambda stacks
- wrapper workflows do not pass Lambda matrices; update this manifest to add, remove, or remap deployed Lambdas
- `after_deploy: invoke` can be set on a manifest entry when the deployed Lambda should be invoked after CodeDeploy completes
- the Lambda build flow installs `requirements.txt` into a per-Lambda build directory
- it copies Python source files into the zip artifact
- markdown files in Lambda source trees are documentation only and are pruned before the zip artifact is created
- manifest detection alone is not enough: the runtime still needs the declared Terragrunt stack to participate in infra apply and code rollout correctly

## Boilerplate Patterns

- the `migrations` Lambda shape is currently a minimal smoke target

## Logging

- logs are written to stdout so they appear in the function's CloudWatch log group

## Runtime Documentation

- add a `README.md` inside a concrete Lambda directory when the function has non-trivial business logic
- use that README to explain what the Lambda does, the event shape it expects, important downstream integrations, and any operational or failure-mode notes

## Related Docs

- migrations deployment rules: [infra/modules/aws/migrations/README.md](../infra/modules/aws/migrations/README.md)
- shared infra context: [infra/README.md](../infra/README.md)
