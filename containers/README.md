# `containers`

Container source directories for this boilerplate.

## Structure

- `worker/` is the fixed ECS service source directory used by CI
- the `debug` image is built from the root `Dockerfile` `debug` target as a support image
- the deployable ECS runtime also needs `task_worker` and `service_worker` live Terragrunt stacks

## Common Shape

- `<service>/app.py`
- `<service>/requirements.txt`
- optional `<service>/README.md` for service-specific application logic and runtime notes

## Build Behavior

- CI builds `worker` and `debug` images directly
- the `worker` image maps to `containers/worker`
- the `debug` image is built alongside `worker` because task definitions can include the debug sidecar
- deploy workflows apply `infra/live/<environment>/aws/task_worker`, then roll `infra/live/<environment>/aws/service_worker`
- container images copy only the files referenced by the Dockerfile for the selected service shape
- markdown files in `containers/` are documentation only and are not included in container image artifacts
- runtime shape validation expects `containers/worker` and the dev/prod `task_worker` / `service_worker` live stacks
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
- shared infra context: [README.md](../README.md)
