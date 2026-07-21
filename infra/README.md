# Infra Notes

Shared infra notes for saved plans and Terragrunt graph debugging.

## Terragrunt State

State is stored under:

```text
s3://<account>-<region>-<repo>-tfstate/<environment>/<provider>/<module>/terraform.tfstate
```

Terraform S3 backend lock files sit next to state objects with the `.tflock`
suffix.

## Concepts

- Saved plans: plan runs write one `terragrunt.tfplan` and one
  `terragrunt.plan.json` per live stack directory.

## Terragrunt Graph Helpers

Use these commands when debugging stack ordering or local Terragrunt graph
output.

Terragrunt derives account-scoped names from `AWS_ACCOUNT_ID`. The repo-root
`just tg`, `just tg-all`, and `just tg-graph` recipes resolve it with
`aws sts get-caller-identity`. Set it yourself only when running Terragrunt
directly or using non-root justfiles:

```sh
export AWS_ACCOUNT_ID=<your AWS account id>
```

If you only need the raw Terragrunt graph output:

```sh
just tg-graph dev > graph.txt
```

That runs the same non-interactive Terragrunt graph command as the root helper:

```sh
cd infra/live/dev/aws
terragrunt run-all graph-dependencies \
  --terragrunt-non-interactive \
  --terragrunt-include-external-dependencies
```

For a saved-plan run:

```sh
just tg dev aws/security plan
```

The shared Terragrunt root always writes `terragrunt.tfplan` into the live
stack directory, so it lands beside that stack's `terragrunt.hcl` instead of
inside `.terragrunt-cache`.

For multi-stack saved-plan runs:

```sh
just tg-all dev plan
```

That writes one `terragrunt.tfplan` file per live stack directory under
`infra/live/<env>/**`.

To inspect that saved plan as JSON, use `show` without repeating the filename:

```sh
just tg dev aws/security show
just tg-all dev show
```

The shared Terragrunt root adds `-json terragrunt.tfplan` for `show`, so each
module reads its saved plan file from the live stack directory. An `after_hook`
also writes that JSON to `terragrunt.plan.json` beside the stack's
`terragrunt.tfplan`.

To list the modules that produced `terragrunt.plan.json` for one environment:

```sh
just --justfile scripts/ci/justfile plan-json-files-list-modules dev
```

That returns an array like:

```json
["aws/security"]
```

To build the per-module `has_changes` summary from that list:

```sh
MODULE_PATHS_JSON="$(just --justfile scripts/ci/justfile plan-json-files-list-modules dev)" \
just --justfile scripts/ci/justfile plan-json-files-to-change-summary dev
```

That returns an array like:

```json
[{"module":"aws/security","has_changes":true}]
```

The summary recipe reads each `infra/live/<env>/<module>/terragrunt.plan.json`,
matches Terraform resource actions `create`, `update`, and `delete`, and also
treats non-empty `output_changes` as a change.

To apply that same saved plan later:

```sh
just tg dev aws/security 'apply terragrunt.tfplan'
```

To make `terragrunt apply` consume the saved `terragrunt.tfplan`
automatically for each module, set:

```sh
TG_USE_SAVED_PLAN=true
```

The shared Terragrunt root then appends each module's
`<live stack>/terragrunt.tfplan` path to `apply`. This is intended for the
saved-plan path when restored plan files already exist in the live stack
directories.
