# Discovery And Runtime Links

Use this when changing fixed runtime links, repo-local action discovery, or Terragrunt graph waves.

## Directory Discovery

`shared_directories_get.yml` derives repo-local action matrices used by PR action-test discovery.

Lambda deployment is fixed-shape:

- `shared_build.yml` builds `lambdas/migrations` directly.
- the Lambda artifact key is `lambdas/<version>/migrations.zip`.
- `shared_deploy.yml` rolls that artifact out to `infra/live/<environment>/aws/migrations`.
- the migrations Lambda is invoked after CodeDeploy completes.

ECS deployment is fixed-shape:

- `shared_build.yml` builds `worker` and `debug` images directly.
- `worker` maps to `containers/worker`.
- `debug` is the support image built from the root `Dockerfile` `debug` target.
- `shared_deploy.yml` applies `infra/live/<environment>/aws/task_worker`, then rolls `infra/live/<environment>/aws/service_worker`.

Top-level runtime discovery rules:

- `lambdas/migrations` is the only Lambda deploy source.
- `containers/worker` is the only service image source.
- adding another runtime requires adding explicit CI jobs and live stack links.

## Module Discovery

`shared_get_modules.yml` is the reusable module-discovery workflow for infra waves.

- Renders the Terragrunt graph for the target environment.
- Converts that graph into compact JSON.
- Derives dependency-safe waves.
- Exposes `waves_json` and `wave_0_modules` through `wave_3_modules` as reusable-workflow outputs.
- The static workflow wave outputs/jobs must be kept aligned with the dependency depth required by the live environment subset being deployed.

Filtering inputs:

- `ignore_task_modules: true` excludes `task_*` modules from emitted waves. Infra plan/apply callers use this because task-definition stacks belong to code deploy, not shared infra rollout.
- `ignore_shared_artifact_modules: true` omits shared artifact stacks such as `code_bucket` and `ecr`.
- `ignore_oidc_module: true` excludes `oidc` entirely.
- `show_wave_summary: false` suppresses the wave overview step summary when a caller provides a more focused summary.
- `wave_summary_title`, `wave_summary_note`, and `wave_summary_order` let callers label the overview and render rows in forward or reverse execution order.
- `show_wave_json: true` includes the raw wave JSON below the overview for debugging.

## Graph To Waves Helper

`just --justfile justfile.ci tg-graph-json-to-waves` expects compact graph JSON in `TG_GRAPH_JSON`.

It returns a sequential JSON array of wave objects:

```json
[{ "wave": 0, "modules": [] }]
```

Each wave contains only modules whose direct dependencies were satisfied by earlier waves.

## Runtime Coverage Checks

- If Lambda runtime links change, confirm the source path exists, the artifact key is updated, and each live stack path exists for every deployed environment.
- If ECS runtime links change, confirm each image source/target exists and each task/service stack path exists for every deployed environment.
- For `*_code` wrappers, confirm dispatch inputs cover every runtime being deployed.
- If ECS deploys are included, confirm `ecs_version` is exposed or intentionally derived.
