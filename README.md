# AWS Terragrunt Starter

Minimal Terragrunt starter for a shared AWS security-group stack across `dev`
and `prod`.

See [infra/README.md](infra/README.md) for state and Terragrunt graph notes.

AI agents working in this repository should read
[REPO_INSTRUCTIONS.md](REPO_INSTRUCTIONS.md) before making changes.

## Useful Commands

```sh
just --list
just tg dev aws/security plan
just tg-all dev plan
```

## Concepts

Environments can map to separate AWS accounts to support AWS
[Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
isolation:

- `dev`: default environment for local iteration.
- `prod`: second environment using the same module shape.

## AWS Prerequisites

This starter **does not** create the VPC. The target AWS account and region
must already contain:

- a VPC with a `Name` tag matching `vpc_name` in
  `infra/live/global_vars.hcl`

The local network check helper also validates that the VPC has public and
private subnets tagged with `public` and `private` in their names:

```sh
just check-network vpc
```

## Local Planning

```sh
export AWS_PROFILE=default
export AWS_REGION=eu-west-2

just tg dev aws/security plan
just tg prod aws/security plan
```

## Docs

- Infrastructure notes: [infra/README.md](infra/README.md)
