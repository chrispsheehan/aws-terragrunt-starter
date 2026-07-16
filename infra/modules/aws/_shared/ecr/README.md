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

Bootstrap ECS task definitions still use the stable `:bootstrap` tag, but the
tag is now seeded by workflow automation after the repository is applied rather
than by Terraform's Docker provider.
