# AWS Terragrunt Starter

Minimal AWS Terragrunt-based starter for reliable deployments across multiple
environments.

GitHub workflow jobs are generated from the infrastructure configuration. See
[workflow docs](.github/docs/README.md) for workflow detail and
[infra/README.md](infra/README.md) for state and Terragrunt graph notes.

## Useful Commands

```sh
just --list
just tg-all dev plan
```

## Concepts

Environments can map to separate AWS accounts to support AWS
[Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
isolation:

- `ci`: stores shared code artifacts.
- `dev`: builds and deploys ephemeral code artifacts outside the `ci`
  environment.
- `prod`: deploys promoted code artifacts from `ci`. The same pattern can be
  copied for additional environments such as `qa`.

## AWS Prerequisites

The AWS account must already have the GitHub OIDC provider for
`https://token.actions.githubusercontent.com`.

This starter **does not** create the VPC or subnets. The target AWS account and
region must already contain:

- a VPC with a `Name` tag matching `vpc_name` in
  `infra/live/global_vars.hcl`
- public subnets in that VPC with `Name` tags containing `public`
- private subnets in that VPC with `Name` tags containing `private`

Check the prerequisite from your local shell:

```sh
just check-network vpc
```

## Initial OIDC Bootstrap

OIDC-enabled roles are required before CI workflows can run. Create them once
from a local shell with AWS credentials that can manage IAM:

```sh
export AWS_PROFILE=default
export AWS_REGION=eu-west-2

just tg ci aws/oidc apply
just tg dev aws/oidc apply
just tg prod aws/oidc apply
```

## GitHub Actions Variables

**Do not add static AWS access keys to GitHub for this starter.**

Set these repository variables in GitHub under
`Settings -> Secrets and variables -> Actions -> Variables`:

```text
AWS_ACCOUNT_ID=<your AWS account id>
AWS_REGION=eu-west-2
PROJECT_NAME=aws-terragrunt-starter
```

`PROJECT_NAME` must match the repository name used when creating the OIDC
roles. For example, view the dev role ARN with:

```sh
just tg dev aws/oidc output
```

For this repository, the role name contains
`aws-terragrunt-starter-dev-github-oidc-role`, so `PROJECT_NAME` is
`aws-terragrunt-starter`.

The workflows use these variables to assume roles named:

```text
<PROJECT_NAME>-<ENVIRONMENT>-github-oidc-role
```

## Docs

- Infrastructure and workflow notes: [infra/README.md](infra/README.md)
- Lambda layout: [lambdas/README.md](lambdas/README.md)
- Container layout: [containers/README.md](containers/README.md)
