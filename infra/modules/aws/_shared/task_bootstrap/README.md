# `_shared/task_bootstrap`

Shared bootstrap ECS task-definition wrapper.

## Owns

- bootstrap ECS task definition via `_shared/task`
- bootstrap task execution role with scoped ECR pull permissions
- bootstrap task role
- bootstrap log group

## Key Inputs

- `ecr_repository_name`
- `aws_region`

## Key Outputs

- `task_definition_arn`
- `service_name`
- log group name

Use this only for bootstrap service applies that need a stable task definition
before the real service task has been published. Runtime task revisions should
continue to come from concrete task wrappers such as `task_worker`.

The bootstrap container writes `/usr/share/nginx/html/health` before starting
nginx, and the ECS container health check verifies that file is present and
non-empty.

The image URI is derived from the current AWS account, `aws_region`,
`ecr_repository_name`, and the stable `:bootstrap` tag. The ECR stack must
publish that tag before a bootstrap service apply can successfully start tasks.
