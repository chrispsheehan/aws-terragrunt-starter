# `containers`

Container source directories for this boilerplate.

## Structure

- `deploy.yml` is the ECS image build/service deploy manifest
- each deployable service lives in its own top-level directory such as `worker/`
- a deployable ECS runtime also needs the live Terragrunt task and service stacks declared by its manifest entry

## Common Shape

- `<service>/app.py`
- `<service>/requirements.txt`
- optional `<service>/README.md` for service-specific application logic and runtime notes

## Build Behavior

- ECS discovery reads `containers/deploy.yml`
- `task_stack` and `service_stack` are repo-relative Terragrunt stack path templates and must use `{environment}` for the environment segment, for example `infra/live/{environment}/aws/task_worker`
- `image` is the ECR image tag prefix and maps to the default source directory `containers/<image>`
- build workflows deduplicate by `image`; deploy workflows keep every manifest entry so the same image can roll out to multiple ECS services
- wrapper workflows do not pass ECS or task matrices; update this manifest to add, remove, or remap deployed ECS services
- `support_images` lists shared images such as `debug` that are built alongside service images because task definitions require them
- container images copy only the files referenced by the Dockerfile for the selected service shape
- markdown files in `containers/` are documentation only and are not included in container image artifacts
- manifest detection alone is not enough: the runtime still needs the declared Terragrunt task and service stacks
- local Docker scaffolding is not currently included in this repo

## Boilerplate Patterns

- HTTP services can be paired with `task_<name>` and `service_<name>` wrappers
- internal workers can use non-HTTP health checks

## Logging

- logs are written to stdout so the ECS log driver forwards them to CloudWatch

## Runtime Documentation

- add a `README.md` inside a concrete service directory when the container has non-trivial request handling, worker behavior, or integration logic
- use that README to explain what the service does, the interfaces it exposes or consumes, important dependencies, and any operational or failure-mode notes

## Related Docs

- ECS service rules: [infra/modules/aws/service_worker/README.md](../infra/modules/aws/service_worker/README.md)
- shared infra context: [infra/README.md](../infra/README.md)
