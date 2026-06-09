# aws-terragrunt-starter

Minimal AWS Terragrunt starter for a Lambda deploy surface and an ECS worker
service.

## Current Shape

- Lambda: `lambdas/migrations`
- ECS container: `containers/worker`
- Infra stacks:
  - `oidc`
  - `code_bucket`
  - `ecr`
  - `cluster`
  - `security`
  - `task_worker`
  - `service_worker`
  - `migrations`


## Deploy Model

- Lambda deploys use CodeDeploy all-at-once.
- ECS deploys use native ECS rolling deployments.
- Lambda deploys are wired directly from `lambdas/migrations` to `infra/live/<environment>/aws/migrations`.
- ECS deploys are wired directly from `containers/worker` to `task_worker`, then `service_worker`.

## Useful Commands

```sh
just --list
just tg-all dev plan
```

## Initial OIDC Bootstrap

Run these once from a local shell that already has AWS credentials capable of
managing IAM. These create the GitHub Actions deploy roles that later workflows
assume with OIDC:

```sh
export AWS_PROFILE=default
export AWS_REGION=eu-west-2

just tg ci aws/oidc apply
just tg dev aws/oidc apply
just tg prod aws/oidc apply
```

The AWS account must already have the GitHub OIDC provider for
`https://token.actions.githubusercontent.com`.

## Docs

- Infra layout: [infra/README.md](infra/README.md)
- Lambda layout: [lambdas/README.md](lambdas/README.md)
- Container layout: [containers/README.md](containers/README.md)
