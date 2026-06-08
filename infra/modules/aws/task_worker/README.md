# `task_worker`

Concrete ECS worker task wrapper.

## Owns

- worker ECS task definition via `_shared/task`

## Does Not Own

- ECS service rollout or autoscaling behavior
- shared cluster creation

## Inputs That Change Behavior

- runs `python -u app.py`
- publishes worker task revisions for ECS deploys
- uses the shared ECR repository named by `ecr_repository_name`
- sets a heartbeat-file health check for the MVP worker
- defaults `local_tunnel` and `xray_enabled` to `false` unless explicitly enabled
- when `local_tunnel` is enabled, the debug sidecar can be reached with ECS Exec

## Outputs Consumers Rely On

- `task_definition_arn`
- `service_name`
- log group name

## Runtime Shape

- ECS worker task
- paired with `service_worker`
- heartbeat-file health check instead of an HTTP health endpoint

## Dependency Notes

- publishes the task definition consumed by `service_worker`

This module is the image-driven deployment unit for the ECS worker. The current
worker source is an MVP smoke target with no database or queue dependency.
