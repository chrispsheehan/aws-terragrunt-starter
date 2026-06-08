# `_shared/task`

Shared ECS task-definition module.

## Owns

- ECS task definition
- task execution role
- task role
- log groups
- optional debug sidecar

## Key inputs

- `image_uri`
- `ecr_repository_name`
- `debug_uri`
- `local_tunnel`
- `command`
- optional `health_check`

In the concrete ECS task wrappers in this repo, `local_tunnel` defaults to
`false` unless the environment explicitly opts in. `xray_enabled` is currently
only passed through as an environment flag for compatibility; this repo no
longer includes OpenTelemetry worker code.

## Key outputs

- `task_definition_arn`
- `service_name`
- log group names

Use this for task revision creation. Traffic rollout happens at the service layer.

The ECR repository access policy uses the explicit `ecr_repository_name` input and derives the repository ARN from the current account, region, and name. That keeps task stacks planable during bootstrap before the artifact repository stack has been applied.

When `health_check` is set, the module adds an ECS container health check to the main service container.
When `local_tunnel` is true, the debug sidecar inherits the same shared and
task-specific environment variables as the main app container.
