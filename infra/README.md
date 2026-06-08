# Infra

This directory contains the Terraform modules and Terragrunt live stacks for the
current repo shape.

## Structure

- `infra/root.hcl`
  Shared Terragrunt root config. It owns remote state naming, generated AWS
  provider config, shared inputs, and repo naming conventions.
- `infra/modules/aws`
  Terraform modules used by live stacks.
- `infra/live/<environment>/aws/<stack>`
  Environment-specific Terragrunt stacks.

## Environments

- `dev`
  Development runtime stacks plus dev-owned artifact resources.
- `prod`
  Production runtime stacks. Runtime deploys read shared artifacts from the
  CI-owned artifact resources.
- `ci`
  Shared artifact infra: `oidc`, `ecr`, and `code_bucket`.

Current live stacks:

- `ci`: `oidc`, `ecr`, `code_bucket`
- `dev`: `oidc`, `ecr`, `code_bucket`, `cluster`, `security`, `task_worker`,
  `service_worker`, `migrations`
- `prod`: `oidc`, `cluster`, `security`, `task_worker`, `service_worker`,
  `migrations`

## State Naming

The root Terragrunt file derives state paths from the live stack path:

- bucket: `<account>-<region>-<repo>-tfstate`
- key: `<environment>/<provider>/<module>/terraform.tfstate`

For example:

```text
infra/live/dev/aws/task_worker/terragrunt.hcl
dev/aws/task_worker/terraform.tfstate
```

The Terraform S3 backend uses `use_lockfile = true`, so each lock is an S3
object next to the state key:

```text
<environment>/<provider>/<module>/terraform.tfstate.tflock
```

Only remove a lock after confirming no Terraform or Terragrunt command is still
running for that stack.

## Module Types

- `_shared/cluster`
  ECS cluster building block.
- `_shared/code_bucket`
  S3 bucket for Lambda zips and Lambda CodeDeploy AppSpec bundles.
- `_shared/ecr`
  Shared ECR repository and bootstrap image.
- `_shared/oidc`
  GitHub Actions OIDC role.
- `_shared/task`
  ECS task definition, task roles, log group, and optional debug sidecar.
- `security`
  Shared runtime security group.
- `task_worker`
  Concrete ECS worker task definition wrapper.
- `service_worker`
  Concrete ECS worker service wrapper using native ECS rolling deployments.
- `migrations`
  Minimal deployable Lambda surface with all-at-once Lambda CodeDeploy wiring.

Removed starter modules such as frontend, messaging, observability, database,
API, and Cognito are not part of the current live graph.

## Stack Responsibilities

- `oidc`
  IAM role and policies used by GitHub Actions.
- `code_bucket`
  Deployment artifact bucket.
- `ecr`
  Container image repository and bootstrap image tag.
- `cluster`
  ECS cluster.
- `security`
  Runtime security group outputs consumed by `migrations` and `service_worker`.
- `task_worker`
  ECS task definition for `containers/worker`.
- `service_worker`
  ECS service for the worker task. Rollout is native ECS rolling deployment.
- `migrations`
  Lambda function, alias, CloudWatch log group, and Lambda CodeDeploy resources.
  Lambda rollout is all-at-once.

## Deployment Model

Infra applies create the stable runtime shape. Code deploy workflows publish new
Lambda versions and ECS task revisions into that shape.

- Lambda deploys use CodeDeploy with all-at-once traffic shifting.
- ECS deploys use the native ECS rolling deployment controller.
- Lambda deploy records come from `lambdas/deploy.yml`.
- ECS deploy records come from `containers/deploy.yml`.

Do not apply a saved plan that captured Terragrunt dependency mocks. For first
deploys, apply upstream stacks first, then re-plan downstream consumers so real
outputs replace mocks.

## Dependency Notes

- use Terragrunt `dependency` blocks for cross-stack values
- keep dependency blocks in the consuming live stack so graph commands can see
  direct edges
- mock dependency outputs only for non-apply commands such as `plan`,
  `validate`, `show`, and graph helpers
- keep mock output names aligned with real producer output names
- avoid `data.terraform_remote_state` unless the dependency is external to the
  Terragrunt graph

Current runtime dependencies:

- `migrations` depends on `security`
- `service_worker` depends on `security` and `cluster`
- `task_worker` is independent and publishes the task definition used by code
  deploy workflows

## Verification

After HCL, module, or live stack dependency changes, run:

```sh
just tg-all dev plan
```

For targeted debugging:

```sh
just tg dev aws/security plan
just tg dev aws/task_worker plan
```

## Runtime Network Placement

The current runtime stacks discover the existing VPC by `vpc_name` and use
tagged private subnets. The repo does not create VPC or subnet infrastructure.

Before adding public runtime surfaces, decide the ingress model explicitly:
load balancer or API Gateway, security group restrictions, authentication, and
whether tasks receive public IPs.

## Local Command Surface

- root `justfile`
  developer and Terragrunt commands
- `justfile.ci`
  CI discovery and validation helpers
- `justfile.deploy`
  build and deploy helpers

Examples:

```sh
just tg-all dev plan
just --justfile justfile.ci lambda-get-deploy-matrix
just --justfile justfile.deploy lambda-build
```

## Naming Conventions

- `task_<name>`
  ECS task-definition stack/module
- `service_<name>`
  ECS service stack/module
- concrete Lambda stack names such as `migrations`
  Lambda stacks

Wrapper workflows should not pass Lambda or ECS matrices directly. Update
`lambdas/deploy.yml` or `containers/deploy.yml` instead.
