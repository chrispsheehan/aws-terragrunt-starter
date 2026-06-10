# aws-terragrunt-starter

Minimal AWS Terragrunt starter for a Lambda deploy surface and an ECS worker
service.

## Useful Commands

```sh
just --list
just tg-all dev plan
```

## AWS Network Prerequisite

This starter does not create the VPC or subnets. Before applying the runtime
stacks, the target AWS account and region must already contain:

- a VPC with `Name` tag matching `vpc_name` in `infra/live/global_vars.hcl`
- private subnets in that VPC with `Name` tags containing `private`

The default `vpc_name` is `vpc`. Update `infra/live/global_vars.hcl` if your
pre-existing VPC uses a different `Name` tag.

Check the prerequisite from your local shell:

```sh
just check-network vpc
```

## Terragrunt State

State is stored under:

```text
s3://<account>-<region>-<repo>-tfstate/<environment>/<provider>/<module>/terraform.tfstate
```

Terraform S3 backend lock files sit next to state objects with the
`.tflock` suffix.

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

## GitHub Actions Variables

Set these repository variables in GitHub under
`Settings -> Secrets and variables -> Actions -> Variables`:

```text
AWS_ACCOUNT_ID=<your AWS account id>
AWS_REGION=eu-west-2
PROJECT_NAME=aws-terragrunt-starter
```

`PROJECT_NAME` must match the repository name that Terragrunt derives from the
Git remote when creating the OIDC roles. For this repository, that value is
`aws-terragrunt-starter`. The workflows use these variables to assume roles
named:

```text
<PROJECT_NAME>-ci-github-oidc-role
<PROJECT_NAME>-dev-github-oidc-role
<PROJECT_NAME>-prod-github-oidc-role
```

Do not add static AWS access keys to GitHub for this starter. GitHub Actions
uses OIDC after the bootstrap roles exist. `GITHUB_TOKEN` is provided by GitHub
automatically and does not need to be created manually.

## Docs

- Lambda layout: [lambdas/README.md](lambdas/README.md)
- Container layout: [containers/README.md](containers/README.md)
- Infra workflow notes: [infra/README.md](infra/README.md)
- Lambda module contract: [infra/modules/aws/migrations/README.md](infra/modules/aws/migrations/README.md)
- ECS module contracts: [task_worker](infra/modules/aws/task_worker/README.md),
  [service_worker](infra/modules/aws/service_worker/README.md)
- Shared infra contracts: [oidc](infra/modules/aws/_shared/oidc/README.md),
  [ecr](infra/modules/aws/_shared/ecr/README.md),
  [code_bucket](infra/modules/aws/_shared/code_bucket/README.md)
