# `service_worker`

Concrete ECS worker service wrapper.

## Owns

- worker ECS service

## Does Not Own

- ECS task-definition content

## Inputs That Change Behavior

- uses the worker task revision exported by `task_worker`
- uses placeholder values during bootstrap applies so the first service apply does not require pre-existing task state
- defaults to private subnets with `assign_public_ip = false`

## Outputs Consumers Rely On

- `service_name`
- `cluster_name`
- `container_port`

## Runtime Shape

- ECS worker service
- internal service shape
- uses native ECS rolling deployment

## Dependency Notes

- expects the live Terragrunt stack to pass the shared `cluster` outputs as explicit inputs
- expects the live Terragrunt stack to pass the ECS runtime security group id as an explicit input
- for bootstrap-friendly plan and validate flows, prefer Terragrunt dependency mocks in the live stack rather than sibling state reads inside the module

During bootstrap applies, it can use placeholder task definition values so the
service stack can plan before the first real task revision exists. Re-plan with
real upstream outputs before applying any plan that captured mocks.
