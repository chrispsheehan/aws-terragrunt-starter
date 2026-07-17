# CI And Workflow Contracts

Use this when changing GitHub Actions, repo-local actions, CI helpers, deploy
workflows, or workflow-owned `just` behavior.

## Entry Points

| Workflow | Purpose |
| --- | --- |
| `dev_infra_apply_no_plan.yml` | Applies dev infrastructure using the current commit as the infra ref. |
| `dev_infra_plan.yml` | Plans all dev infrastructure through Terragrunt `run-all`. |
| `dev_infra_apply_from_plan.yml` | Applies dev infra from a prior saved-plan run using `plan_artifact_run_id`. |
| `dev_code_deploy.yml` | Builds fresh dev artifacts and deploys code to dev. |
| `prod_infra_plan.yml` | Plans all prod infrastructure for the requested infra ref through Terragrunt `run-all`. |
| `prod_infra_apply_no_plan.yml` | Applies prod infrastructure using the pinned infra ref. |
| `prod_infra_apply_from_plan.yml` | Applies prod infra from a prior saved-plan run. |
| `prod_code_deploy.yml` | Resolves released artifacts from `ci` and deploys code to prod. |
| `destroy.yml` | Tears down infrastructure by running `terragrunt run-all destroy`. |

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

- Checks workflow syntax, Terraform formatting/linting, changed runtime builds,
  agent-wrapper sync, and direct execution of
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

The shared infra plan/apply/destroy wrappers install Terraform and Terragrunt
first, then execute Terragrunt across the whole environment.

- They follow the same Terragrunt setup pattern as
  `shared_bootstrap_infra.yml`.
- `shared_infra_plan.yml` runs `terragrunt run-all plan`, then
  `terragrunt run-all show`.
- `shared_infra_apply_from_plan.yml` downloads the saved plan metadata, checks
  out the planned infra ref, and then runs `terragrunt run-all apply`.
- `destroy.yml` runs `terragrunt run-all destroy`.

Shared infra wrappers must forward permissions required by the nested reusable
call chain:

- `id-token: write` everywhere the Terragrunt action may assume AWS OIDC
- `contents: read` for checkout

- Shared infra plan/apply wrappers still set `TF_VAR_bootstrap=true` so ECS
  service stacks can create the stable service surface before the first real
  task revision is deployed.

## Saved Plans

`shared_infra_plan.yml` is the saved-plan wrapper.

- Takes resolved workflow inputs directly.
- Runs `terragrunt run-all plan`.
- Runs `terragrunt run-all show` so each stack writes
  `terragrunt.plan.json` beside `terragrunt.tfplan`.
- Builds the per-module `has_changes` summary from those saved JSON files.
- Writes direct workflow inputs plus that change summary into
  `plan-metadata.json`.
- Uploads that file as the GitHub Actions artifact named `infra-plan-metadata`.
- Exposes `plan_artifact_run_id` as a reusable-workflow output.
- Adds a plan summary showing the modules whose saved `terragrunt.plan.json`
  reports `has_changes: true`.

`shared_infra_apply_no_plan.yml` is the direct-input apply wrapper.

- Takes resolved workflow inputs directly.
- Runs `just tg-all <environment> apply`.

`shared_infra_apply_from_plan.yml` is the apply-from-plan wrapper.

- Takes `plan_artifact_run_id`.
- Downloads `infra-plan-metadata` from the earlier workflow run.
- Reads the planned `infra_version` and the saved `changed_modules` summary.
- Checks out that planned `infra_version`.
- Re-runs `terragrunt run-all apply`.
- Uses the saved `changed_modules` array as run metadata and operator context.

Saved infra-plan storage is split into:

- run-level artifact: `infra-plan-metadata`, containing `plan-metadata.json`
- per-stack local files in the checked-out repo: `terragrunt.tfplan` and
  `terragrunt.plan.json`

The shared Terragrunt root owns the saved plan paths.

- `plan` writes `terragrunt.tfplan` into each live stack directory.
- `show` reads that file with `terraform show -json` and writes
  `terragrunt.plan.json` beside it.
- `infra-plan-metadata` is uploaded with `retention-days: 14`.

If apply is deferred to a later workflow run, pass the earlier `run_id` through
`plan_artifact_run_id`. Recovery only works while the metadata artifact is
still retained.

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

`destroy.yml` tears down infrastructure through Terragrunt `run-all`.

- Shares `infra-mutate-<environment>` with mutating apply workflows.
- Runs `terragrunt run-all destroy`.
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
