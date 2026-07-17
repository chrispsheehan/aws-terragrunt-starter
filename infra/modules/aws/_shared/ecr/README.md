# `_shared/ecr`

Shared ECR repository module.

## Owns

- the repository used for ECS images
- repository lifecycle settings

## Key inputs

- `ecr_repository_name`

## Key outputs

- `repository_url`

Used by image build and ECS deploy workflows.

Bootstrap ECS tasks still use the stable `:bootstrap` tag convention, but that
tag is no longer managed by Terraform. CI/bootstrap workflow logic is
responsible for seeding the image into ECR when needed.
