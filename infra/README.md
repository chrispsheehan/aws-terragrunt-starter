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

- Waves: Terragrunt dependencies are split into ordered workflow waves. Apply
  runs foundations first; destroy runs the same waves in reverse. Infra waves
  exclude `task_*` stacks because code deploy owns ECS task revisions.
- Bootstrapping: infra applies create the stable runtime surface before real
  application artifacts exist. Placeholder inputs and `TF_VAR_bootstrap=true`
  keep first-time ECS/Lambda applies planable; code deploy rolls real artifacts
  later.
- Saved plans: plan runs freeze inputs and wave order, then upload one run-level
  metadata artifact plus one plan artifact per changed stack. Apply-from-plan
  uses the source run id, skips unchanged stacks, and must run before artifacts
  expire. Do not apply plans that captured mocked outputs.

## Terragrunt Graph Helpers

Use these commands when debugging stack ordering, workflow wave generation, or
saved-plan metadata joins.

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

To test the wave processor locally through the same split used by CI:

```sh
just tg-graph-waves dev
```

To test the infra plan/apply wave filtering used by PR validation:

```sh
RAW_WAVES_JSON="$(just tg-graph-waves dev)" just --justfile scripts/ci/justfile tg-waves-to-infra-waves
```

To test the destroy wave filtering used by PR validation:

```sh
RAW_WAVES_JSON="$(just tg-graph-waves dev)" just --justfile scripts/ci/justfile tg-waves-to-destroy-waves
```

To run the full static workflow wave-job validation locally:

```sh
RAW_WAVES_JSON="$(just tg-graph-waves dev)"
INFRA_WAVES_JSON="$(RAW_WAVES_JSON="$RAW_WAVES_JSON" just --justfile scripts/ci/justfile tg-waves-to-infra-waves)"
DESTROY_WAVES_JSON="$(RAW_WAVES_JSON="$RAW_WAVES_JSON" just --justfile scripts/ci/justfile tg-waves-to-destroy-waves)"

RAW_WAVES_JSON="$RAW_WAVES_JSON" \
INFRA_WAVES_JSON="$INFRA_WAVES_JSON" \
DESTROY_WAVES_JSON="$DESTROY_WAVES_JSON" \
just --justfile scripts/ci/justfile tg-validate-static-wave-jobs
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

To apply that same saved plan later, reuse the same run id:

```sh
just tg dev aws/oidc 'apply terragrunt.tfplan'
```
