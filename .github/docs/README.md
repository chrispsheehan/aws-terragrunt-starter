# CI And Workflow Contracts

Use this when changing GitHub Actions, repo-local actions, CI helpers, deploy
workflows, or workflow-owned `just` behavior.

## Entry Points

| Workflow | Purpose |
| --- | --- |
| `shared_infra_bootstrap.yml` | Bootstraps infrastructure for the selected environment from the UI or from direct reusable-workflow callers. |
| `dev_infra_plan_and_apply.yml` | Plans dev infrastructure for the requested ref, then applies the same ref through the shared planned-apply workflow. |
| `dev_code_deploy.yml` | Builds fresh dev artifacts and deploys code to dev. |
| `prod_infra_plan.yml` | Plans prod infrastructure in a single `tg-all` run for the requested infra ref. |
| `prod_infra_apply_from_plan.yml` | Applies prod infra for the ref recorded by an earlier plan run. |
| `prod_code_deploy.yml` | Resolves released artifacts from `ci` and deploys code to prod. |
| `destroy.yml` | Tears down infrastructure in a single Terragrunt run-all destroy job, then optionally runs tagged-resource cleanup. |

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

- Checks workflow syntax, Terraform formatting/linting, changed runtime builds, agent-wrapper sync, and direct execution of
  `./.github/actions/get-release-version`.
- The agent-wrapper sync check verifies `AGENTS.md` and `CLAUDE.md` match the standard wrapper directing agents to `REPO_INSTRUCTIONS.md`.
- Its `check` job runs `.github/actions/get-changes` using the PR base SHA for a PR-style `base...HEAD` diff.
- Manual `workflow_dispatch` runs force every change flag on and rerun the full validation surface without a PR diff.
- When `.github/actions/**` changed, it reuses `shared_directories_get.yml` to discover action directories with `Dockerfile`s and runs a Docker unit-test matrix after GitHub formatting.
- When `frontend/**` changed, it runs the frontend static build through `scripts/deploy/justfile`.
## Build And Artifact Resolution

`shared_build.yml` prepares shared artifact infrastructure such as ECR and the
code bucket before publishing artifacts.

- Exposes bucket/repository values as reusable-workflow outputs.
- The build `ecr` and `bucket` jobs apply their live stacks before reading outputs.
- Shared infra apply seeds the stable ECR `:bootstrap` image with `nginx:latest` after the ECR repository exists and before bootstrap ECS services are applied.
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
- `shared_infra_bootstrap.yml` requires a direct `infra_version`, applies the ECR stack, seeds the stable `:bootstrap` image when missing, sets `TF_VAR_bootstrap=true`, and then uses the repo-local Terragrunt action with `tg_action: run_all_apply`.
- `shared_infra_apply_from_plan.yml` recovers `infra_version` from `infra-plan-metadata` and then calls the shared bootstrap workflow with that resolved ref.
- Run-all exclusion lists are passed into the action as plain JSON arrays of module directory names.

Shared infra wrappers must still forward the permissions needed for checkout,
artifact reads, and AWS OIDC:

- `id-token: write`
- `contents: read`
- `actions: read` when recovering plan metadata from another run

- Shared infra plan/apply wrappers no longer derive module waves or fan out GitHub matrices.
- Shared infra plan excludes `aws/task_worker`; shared infra apply excludes both `aws/ecr` and `aws/task_worker` after performing the targeted ECR bootstrap seed step. Code deploy still owns task-definition rollout and passes the real ECS image URIs.
- Shared infra plan/apply wrappers still set `TF_VAR_bootstrap=true` for apply so ECS service stacks can create the stable service surface before the first real task revision is deployed.

## Saved Plans

`shared_infra_plan.yml` uploads one metadata artifact named
`infra-plan-metadata`.

- `plan-metadata.json` stores the requested `environment` and `infra_version`.
- `plan_artifact_run_id` still points at the workflow run that produced that metadata.
- The metadata artifact is retained for 14 days.

`shared_infra_apply_from_plan.yml` uses that metadata to pin apply to the same
infrastructure ref that was planned earlier.

- It does not download or replay per-module Terraform plan artifacts.
- It ultimately reruns the repo-local Terragrunt action in `run_all_apply` mode against current remote state for the recorded ref.

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

`destroy.yml` tears down infrastructure through one repo-local Terragrunt
action run in `run_all_destroy` mode.

- Shares `infra-mutate-<environment>` with mutating apply workflows.
- Always excludes `oidc`.
- Excludes `code_bucket` and `ecr` unless `allow_cleanup` is enabled.
- Sets placeholder artifact vars so ECS and Lambda destroy paths stay planable in automation.
- Writes a short summary showing environment, cleanup mode, and excluded modules before destroy runs.

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
