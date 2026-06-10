# Infra Notes

Shared infra notes for workflow behavior, saved plans, and Terragrunt graph
debugging.

## Deployment Model

Infrastructure apply and feature-code rollout are intentionally decoupled in
this starter.

- Infrastructure applies create the stable runtime surface; rerunning
  infrastructure does not roll out new feature code.
- Bootstrap applies may use placeholder inputs so runtime stacks can create
  stable surfaces before the first real Lambda zip or ECS task revision exists.
- Saved plans are apply-intent artifacts. Do not apply a plan that captured
  bootstrap placeholders or mocked upstream dependency outputs.
- GitHub saved-plan artifacts are keyed by workflow run id, with one run-level
  metadata artifact plus one per-stack plan artifact.
- Saved plan artifacts are time-limited; apply-from-plan must happen before
  artifact expiry.
- Code artifact retention is configured in the shared code bucket module.
- Detailed workflow contracts, reusable-workflow inputs, and repo-local action
  behavior live in [CI docs](../.github/docs/README.md).

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
RAW_WAVES_JSON="$(just tg-graph-waves dev)" just --justfile justfile.ci tg-waves-to-infra-waves
```

To test the destroy wave filtering used by PR validation:

```sh
RAW_WAVES_JSON="$(just tg-graph-waves dev)" just --justfile justfile.ci tg-waves-to-destroy-waves
```

To run the full static workflow wave-job validation locally:

```sh
RAW_WAVES_JSON="$(just tg-graph-waves dev)"
INFRA_WAVES_JSON="$(RAW_WAVES_JSON="$RAW_WAVES_JSON" just --justfile justfile.ci tg-waves-to-infra-waves)"
DESTROY_WAVES_JSON="$(RAW_WAVES_JSON="$RAW_WAVES_JSON" just --justfile justfile.ci tg-waves-to-destroy-waves)"

RAW_WAVES_JSON="$RAW_WAVES_JSON" \
INFRA_WAVES_JSON="$INFRA_WAVES_JSON" \
DESTROY_WAVES_JSON="$DESTROY_WAVES_JSON" \
just --justfile justfile.ci tg-validate-static-wave-jobs
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

For a local saved-plan run, pass the Terragrunt operation as one quoted
argument:

```sh
just tg dev aws/oidc 'plan -out=terragrunt.tfplan'
```

The `tg` recipe treats the final argument as the Terragrunt operation string, so
quoting lets you pass flags such as `-out=...` through the wrapper. The workflow
saved-plan path expects the binary plan filename to be `terragrunt.tfplan`.

To apply that same saved plan later, reuse the same run id:

```sh
just tg dev aws/oidc 'apply terragrunt.tfplan'
```
