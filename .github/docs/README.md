# CI And Workflow Contracts

Use this directory when changing GitHub Actions, repo-local actions, CI helpers, deploy workflows, or workflow-owned `just` behavior.

This README is the router. The contract details live in focused docs so humans and agents can load only the context they need.

## Read Next

| Task | Read |
| --- | --- |
| Find the workflow a user should trigger | This README |
| Change reusable build, infra, deploy, or release workflow behavior | [reusable-workflows.md](reusable-workflows.md) |
| Change saved plan, apply-from-plan, artifact naming, or plan metadata behavior | [artifacts-and-plans.md](artifacts-and-plans.md) |
| Change `.github/actions/**` | This README plus the action's own README |
| Change OIDC role ARN construction | [OIDC module README](../../infra/modules/aws/_shared/oidc/README.md) and [reusable-workflows.md](reusable-workflows.md) |
| Change destroy behavior, post-destroy cleanup, or tagged-resource sweeps | [destroy.md](destroy.md) |

## Workflow Groups

| Group | Workflows |
| --- | --- |
| Release and validation | `release.yml`, `pull_request.yml` |
| Shared artifact prep and build | `shared_infra_releases.yml`, `shared_build.yml`, `shared_build_get.yml` |
| Shared infra and code rollout | `shared_infra_plan.yml`, `shared_infra_apply_no_plan.yml`, `shared_infra_apply_from_plan.yml`, `shared_infra.yml`, `shared_deploy.yml` |
| Discovery | `shared_directories_get.yml`, `shared_get_modules.yml` |
| Environment entry points | `dev_infra_apply_no_plan.yml`, `dev_infra_plan.yml`, `dev_infra_plan_and_apply.yml`, `dev_infra_apply_from_plan.yml`, `dev_code_deploy.yml`, `prod_infra_apply_no_plan.yml`, `prod_infra_plan.yml`, `prod_infra_apply_from_plan.yml`, `prod_code_deploy.yml` |
| Cleanup | `destroy.yml` |

## Entry Points

| Workflow | Purpose |
| --- | --- |
| `dev_infra_apply_no_plan.yml` | Discovers directories, prepares dev artifacts, and applies dev infrastructure. It first prepares shared artifact infrastructure through `shared_infra_releases.yml`, then runs the shared infra apply wrapper with the target environment and infra ref. |
| `dev_infra_plan.yml` | Plans the ordered dev infra graph through `shared_infra_plan.yml`. |
| `dev_infra_plan_and_apply.yml` | Captures the current run as plan context, plans the ordered dev infra graph so metadata and per-stack plan artifacts are emitted, then reapplies the same graph through `shared_infra_apply_from_plan.yml`. |
| `dev_infra_apply_from_plan.yml` | Reapplies the ordered dev infra graph from plan artifacts created by an earlier dev plan run, using `plan_artifact_run_id` end to end. |
| `dev_code_deploy.yml` | Builds fresh dev artifacts, resolves deploy inputs, and deploys code to dev. |
| `prod_infra_plan.yml` | Resolves released artifacts from `ci`, then plans the ordered prod infra graph and emits metadata plus per-stack plan artifacts. |
| `prod_infra_apply_no_plan.yml` | Resolves released artifacts from `ci` and applies prod infrastructure. |
| `prod_infra_apply_from_plan.yml` | Reapplies the ordered prod infra graph from a prior `prod_infra_plan` run. The shared apply-from-plan wrapper reads metadata first, then each apply job downloads its matching per-stack artifact before invoking `apply_plan`. |
| `prod_code_deploy.yml` | Resolves released artifacts from `ci` and deploys code to prod. |

## Concurrency

- `release` uses a single global `release` group.
- Infra plans use `infra-plan-<environment>`.
- Infra applies and destroys use `infra-mutate-<environment>`.
- Code deploys use `deploy-<environment>`.
- Mutating infra workflows share `infra-mutate-<environment>`, so only one apply or destroy can run at a time per environment.

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

Keep split `just` ownership clear:

- repo-root `justfile` for local/developer commands
- `justfile.ci` for read-only CI helpers
- `justfile.deploy` for mutating CI build and deploy steps
- `justfile.destroy` for explicit teardown and post-destroy cleanup steps

## Fast Paths

For most workflow edits:

1. Start with the task-specific doc above.
2. Compare the affected caller and callee workflow contracts before editing.
3. If the change touches Terragrunt graph edges, saved plans, deploy ordering, or runtime shape, also read the relevant infra/runtime README named by `REPO_INSTRUCTIONS.md`.

For reusable workflow inputs, outputs, artifacts, and action behavior, use [reusable-workflows.md](reusable-workflows.md), [artifacts-and-plans.md](artifacts-and-plans.md), and the relevant action README under `.github/actions`.

For destroy behavior, use [destroy.md](destroy.md) before editing `destroy.yml` or `justfile.destroy`.
