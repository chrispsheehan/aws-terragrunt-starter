# CI And Workflow Contracts

Use this when changing GitHub Actions, repo-local actions, CI helpers, deploy
workflows, or workflow-owned `just` behavior.

## Entry Points

| Workflow | Purpose |
| --- | --- |
| `dev_infra_apply_no_plan.yml` | Applies dev infrastructure using the current commit as the infra ref. |
| `dev_infra_plan.yml` | Plans dev infrastructure in a single `tg-all` run. |
| `dev_infra_apply_from_plan.yml` | Applies dev infra for the ref recorded by an earlier plan run. |
| `dev_code_deploy.yml` | Builds fresh dev artifacts and deploys code to dev. |
| `prod_infra_plan.yml` | Plans prod infrastructure in a single `tg-all` run for the requested infra ref. |
| `prod_infra_apply_no_plan.yml` | Applies prod infrastructure using the pinned infra ref. |
| `prod_infra_apply_from_plan.yml` | Applies prod infra for the ref recorded by an earlier plan run. |
| `prod_code_deploy.yml` | Resolves released artifacts from `ci` and deploys code to prod. |
| `destroy.yml` | Tears down infrastructure through the Terragrunt graph in reverse wave order. |

## Contract Checks

When changing reusable workflows:

- Compare every caller `with:` block against the callee `workflow_call.inputs`.
- Compare expected outputs against actual `jobs.<job>.outputs.*`.
- Confirm every `needs.<job>.outputs.*` reference is in scope.
- Verify optional inputs are intentionally omitted, not accidentally missing.
- Keep job `name:` values human-readable.

For OIDC role ARN construction, also read
[the OIDC module README](../../infra/modules/aws/_shared/oidc/README.md).

## Release And Validation

`release.yml` creates release tags, prepares shared CI artifacts, builds release
outputs, and publishes GitHub releases.

- Version bumps come from `./.github/actions/get-release-version`.
- Default bump rules classify `feat` as minor, `fix` as patch, and `!` or
  `BREAKING CHANGE:` subjects as major.
- `createNewTag` is the tag-creation predicate.
- `createNewRelease` is the full-release predicate.
- The repository uses the action defaults, so major, minor, and patch bumps all
  create full releases.

`pull_request.yml` provides fast validation.

- Checks workflow syntax, Terraform formatting/linting, destroy-wave job
  shape, changed runtime builds, agent-wrapper sync, and direct execution of
  `./.github/actions/get-release-version`.
- The agent-wrapper sync check verifies `AGENTS.md` and `CLAUDE.md` match the standard wrapper directing agents to `REPO_INSTRUCTIONS.md`.
- Its `check` job runs `.github/actions/get-changes` using the PR base SHA for a PR-style `base...HEAD` diff.
- Manual `workflow_dispatch` runs force every change flag on and rerun the full validation surface without a PR diff.
- When `.github/actions/**` changed, it reuses `shared_directories_get.yml` to discover action directories with `Dockerfile`s and runs a Docker unit-test matrix after GitHub formatting.
- When `frontend/**` changed, it runs the frontend static build through `scripts/deploy/justfile`.
- When workflow, Terraform, or Terragrunt files change, it runs
  `just tg-graph-waves dev` and fails if the generated wave depth does not
  match the static `wave_N` jobs in `destroy.yml`.

## Build And Artifact Resolution

`shared_build.yml` prepares shared artifact infrastructure such as ECR and the
code bucket before publishing artifacts.

- Exposes bucket/repository values as reusable-workflow outputs.
- The build `ecr` and `bucket` jobs apply their live stacks before reading outputs.
- The Terraform ECR module owns the stable bootstrap `:bootstrap` image through the Docker provider.
- The code-bucket job reads Lambda and AppSpec S3 prefix names from `scripts/ci/justfile` recipes and forwards them as `TF_VAR_*`.

`shared_build.yml` builds and publishes Lambda and ECS artifacts.

- Lambda builds upload `lambdas/migrations` as `migrations.zip`.
- Frontend builds upload `frontend.zip` under `frontend/<version>/`.
- ECS image builds push `worker` and `debug` tags for the requested `ecs_version`.

`shared_build_get.yml` resolves artifact locations used by downstream deploy
wrappers.

- Prod deploy resolution checks `lambdas/<version>/migrations.zip` exists in the shared code bucket.
- Prod deploy resolution checks `frontend/<version>/frontend.zip` exists in the shared code bucket.
- Prod deploy resolution checks `worker-<version>` and `debug-<version>` exist in ECR.

## Shared Infra Wrappers

The shared infra plan/apply wrappers execute one environment-wide `tg-all` run
per workflow.

- `shared_infra_plan.yml` checks out the requested infra ref, configures AWS OIDC, and uses the repo-local Terragrunt action with `tg_action: run_all_plan`.
- `shared_infra_apply_no_plan.yml` checks out the requested infra ref, sets bootstrap and placeholder artifact vars, and uses the repo-local Terragrunt action with `tg_action: run_all_apply`.
- `shared_infra_apply_from_plan.yml` downloads `infra-plan-metadata`, recovers the planned `infra_version`, then runs the same single run-all apply flow for that ref through the repo-local Terragrunt action.

Shared infra wrappers must still forward the permissions needed for checkout,
artifact reads, and AWS OIDC:

- `id-token: write`
- `contents: read`
- `actions: read` when recovering plan metadata from another run

- Shared infra plan/apply wrappers no longer derive module waves or fan out GitHub matrices.
- Shared infra plan/apply wrappers still set `TF_VAR_bootstrap=true` for apply so ECS service stacks can create the stable service surface before the first real task revision is deployed.
- Shared infra plan/apply wrappers also set the same placeholder artifact env vars the old `tg-all` recipe exported: `TF_VAR_lambda_version`, `TF_VAR_image_uri`, and `TF_VAR_debug_uri`.

`shared_get_modules.yml` still drives destroy-wave discovery and supports these
filtering inputs:

- `ignore_task_modules: true` excludes `task_*` modules from emitted waves.
- `ignore_shared_artifact_modules: true` omits shared artifact stacks such as `code_bucket` and `ecr`.
- `ignore_oidc_module: true` excludes `oidc`.
- `show_wave_summary: false` suppresses the wave overview step summary.
- `wave_summary_title`, `wave_summary_note`, and `wave_summary_order` label the overview and choose forward or reverse row order.
- `show_wave_json: true` includes raw wave JSON below the overview for debugging.

## Saved Plans

`shared_infra_plan.yml` uploads one metadata artifact named
`infra-plan-metadata`.

- `plan-metadata.json` stores the requested `environment` and `infra_version`.
- `plan_artifact_run_id` still points at the workflow run that produced that metadata.
- The metadata artifact is retained for 14 days.

`shared_infra_apply_from_plan.yml` uses that metadata only to pin the apply to
the same infrastructure ref that was planned earlier.

- It does not download or replay per-module Terraform plan artifacts.
- It reruns the repo-local Terragrunt action in `run_all_apply` mode against current remote state for the recorded ref.

When a live Terragrunt `dependency` block uses `mock_outputs` for planability or
destroy safety, default it to:

```hcl
mock_outputs_merge_strategy_with_state = "shallow"
```

That prevents partial real upstream state from suppressing missing mock keys.

## Code Deploy

`shared_code_deploy.yml` rolls out feature code.

- Its `Summary` job writes the fixed code deploy target summary.
- Syncs the selected frontend artifact into the public S3 website bucket when a frontend version is provided.
- Publishes the `migrations` Lambda version.
- Invokes the `migrations` Lambda after CodeDeploy completes.
- Applies the `task_worker` stack with `worker` and `debug` image URIs.
- Updates the `service_worker` ECS service.

Ownership boundary:

- `*_infra` wrappers stop at infrastructure apply.
- `shared_code_deploy.yml` owns feature-code rollout.
- Prod wrappers read shared artifact resources from `ci` while applying deploy targets in `prod`.
- Prod deploy wrappers do not create shared artifact infrastructure; release builds own that path.

## Destroy

`destroy.yml` tears down infrastructure through the Terragrunt graph in reverse
shared-infra wave order.

- Shares `infra-mutate-<environment>` with mutating apply workflows.
- Derives current module waves through `shared_get_modules.yml`.
- Uses filtering inputs to omit `oidc` entirely.
- Omits `code_bucket` and `ecr` unless `allow_cleanup` is enabled.
- Writes the shared module-discovery wave summary in reverse order.
- Runs `wave_2` through `wave_0` in reverse dependency order.
- The only remaining module-specific destroy placeholder vars are required ECS task image inputs for `task_*`.

When `allow_cleanup` is enabled:

- The workflow first counts tagged leftovers through `scripts/destroy/justfile`.
- It prints a warning only when leftovers remain.
- It then runs the cleanup recipe.
- Cleanup deregisters and deletes tagged ECS task-definition revisions.
- Cleanup force-deletes tagged Secrets Manager secrets.
- Cleanup validates those resource types against underlying service APIs rather than treating the tagging index as source of truth.
- Unsupported or still-live tagged resources after cleanup are recorded as workflow warnings and step-summary entries rather than failing the whole destroy run.

## Repo-Local Actions

Repo-local GitHub Actions live under `.github/actions`, so workflow `uses:`
references point at local paths instead of external action tags.

- [get-changes](../actions/get-changes/README.md)
- [get-release-version](../actions/get-release-version/README.md)
- [just](../actions/just/README.md)
- [terragrunt](../actions/terragrunt/README.md)

When a repo-local action needs AWS, configure credentials in the workflow job
before calling the action. The local action should reuse that ambient AWS
session.

## Concurrency

- `release` uses a single global `release` group.
- Infra plans use `infra-plan-<environment>`.
- Infra applies and destroys use `infra-mutate-<environment>`.
- Code deploys use `deploy-<environment>`.
- Mutating infra workflows share `infra-mutate-<environment>`, so only one apply or destroy can run at a time per environment.
