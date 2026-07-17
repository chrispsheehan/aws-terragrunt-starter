# Infra Notes

Shared infra notes for workflow behavior, saved plans, and Terragrunt graph
debugging.

## Terragrunt State

State is stored under:

```text
s3://<account>-<region>-<repo>-tfstate/<environment>/<provider>/<module>/terraform.tfstate
```

Terraform S3 backend lock files sit next to state objects with the `.tflock`
suffix.

## Concepts

- Bootstrapping: infra applies create the stable runtime surface before real
  application artifacts exist. Placeholder inputs and `TF_VAR_bootstrap=true`
  keep first-time ECS/Lambda applies planable; code deploy rolls real artifacts
  later.
- Saved plans: plan runs write one `terragrunt.tfplan` and one
  `terragrunt.plan.json` per live stack directory, then upload run-level plan
  metadata for later apply context. Do not apply plans that captured mocked
  outputs.

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

To return the direct dependencies for every module as a JSON object:

```sh
just tg-all-module-dependencies dev
```

If you only need the raw Terragrunt graph output:

```sh
just tg-graph dev > graph.txt
```

That runs the same non-interactive Terragrunt graph command used in CI:

```sh
cd infra/live/dev/aws
terragrunt run-all graph-dependencies \
  --terragrunt-non-interactive \
  --terragrunt-include-external-dependencies
```

To process that saved graph file into compact dependency JSON:

```sh
just tg-graph-process graph.json dev
```

To return only changed saved-plan items as an object array, set the saved-plan
env vars and run:

```sh
BUCKET_NAME=<code-bucket-name> \
TG_GRAPH_METADATA_PLAN_RUN_ID=<plan-run-id> \
just tg-graph-changed-items graph.json dev
```

To join the processed graph with saved-plan metadata for one plan run, set the
saved-plan env vars before running the processing command:

```sh
BUCKET_NAME=<code-bucket-name> \
TG_GRAPH_METADATA_PLAN_RUN_ID=<plan-run-id> \
just tg-graph-process graph.json dev
```

For a saved-plan run, pass the Terragrunt operation as one quoted argument:

```sh
just tg dev aws/oidc plan
```

The `tg` recipe treats the final argument as the Terragrunt operation string, so
quoting lets you pass additional flags through the wrapper when needed. The
shared Terragrunt root always writes `terragrunt.tfplan` into the live stack
directory, so it lands beside that stack's `terragrunt.hcl` instead of inside
`.terragrunt-cache`. The workflow saved-plan path expects the binary plan
filename to be `terragrunt.tfplan`.

For multi-stack saved-plan runs:

```sh
just tg-all dev plan
```

That writes one `terragrunt.tfplan` file per live stack directory under
`infra/live/<env>/**`.

To inspect that saved plan as JSON, use `show` without repeating the filename:

```sh
just tg dev aws/oidc show
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
["aws/oidc","aws/task_worker"]
```

To build the per-module `has_changes` summary from that list:

```sh
MODULE_PATHS_JSON="$(just --justfile scripts/ci/justfile plan-json-files-list-modules dev)" \
just --justfile scripts/ci/justfile plan-json-files-to-change-summary dev
```

That returns an array like:

```json
[{"module":"aws/oidc","has_changes":false},{"module":"aws/task_worker","has_changes":true}]
```

The summary recipe reads each `infra/live/<env>/<module>/terragrunt.plan.json`,
matches Terraform resource actions `create`, `update`, and `delete`, and also
treats non-empty `output_changes` as a change.

For apply-from-plan selection, the workflow derives a changed-only module-path
array from that summary and excludes `aws/task_worker`. For example:

```json
["aws/oidc"]
```

To apply that same saved plan later, reuse the same run id:

```sh
just tg dev aws/oidc 'apply terragrunt.tfplan'
```

To make `terragrunt apply` consume the saved `terragrunt.tfplan`
automatically for each module, set:

```sh
TG_USE_SAVED_PLAN=true
```

The shared Terragrunt root then appends each module's
`<live stack>/terragrunt.tfplan` path to `apply`. This is intended for the
saved-plan CI path when restored plan files already exist in the live stack
directories.
