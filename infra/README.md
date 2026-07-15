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

- Waves: Terragrunt dependencies are split into ordered workflow waves for
  destroy. Infra plan/apply now run as a single `tg-all` operation, while
  destroy still walks the derived waves in reverse.
- Bootstrapping: infra applies create the stable runtime surface before real
  application artifacts exist. Placeholder inputs and `TF_VAR_bootstrap=true`
  keep first-time ECS/Lambda applies planable; code deploy rolls real artifacts
  later.
- Planned refs: plan runs upload `infra-plan-metadata` with the requested
  `environment` and `infra_version`. Apply-from-plan reuses that metadata to
  apply the same ref later, but it does not replay saved per-module Terraform
  plan files.

## Terragrunt Graph Helpers

Use these commands when debugging stack ordering, destroy-wave generation, or
plan metadata.

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

To test the destroy wave filtering used by PR validation:

```sh
RAW_WAVES_JSON="$(just tg-graph-waves dev)" just --justfile scripts/ci/justfile tg-waves-to-destroy-waves
```

To run the full static workflow wave-job validation locally:

```sh
RAW_WAVES_JSON="$(just tg-graph-waves dev)"
DESTROY_WAVES_JSON="$(RAW_WAVES_JSON="$RAW_WAVES_JSON" just --justfile scripts/ci/justfile tg-waves-to-destroy-waves)"

RAW_WAVES_JSON="$RAW_WAVES_JSON" \
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

To inspect the same environment-wide plan path used by CI:

```sh
just tg-all dev plan
```

To apply the same environment-wide path used by CI:

```sh
just tg-all dev apply
```
