# List root recipes plus split CI/deploy recipe files.
_default:
    @just --list
    @printf '\nCI recipes (`just --justfile scripts/ci/justfile --list`):\n'
    @just --justfile scripts/ci/justfile --list


PROJECT_DIR := justfile_directory()


# Delete local git branches whose upstream refs have gone away.
git-tidy:
    #!/usr/bin/env bash
    git fetch --prune
    for branch in $(git branch -vv | grep ': gone]' | awk '{print $1}'); do
        git branch -d $branch
    done


terraform-tidy:
    #!/usr/bin/env bash
    set -euo pipefail

    TARGET_DIR="{{justfile_directory()}}/infra/live"
    echo "Cleaning in: $TARGET_DIR"

    # Remove .terragrunt-cache directories
    find "$TARGET_DIR" -type d -name ".terragrunt-cache" -prune -exec rm -rf {} +

    # Remove .terraform.lock.hcl files
    find "$TARGET_DIR" -type f -name ".terraform.lock.hcl" -exec rm -f {} +

    echo "Done."


# Create and push a new branch from the latest `main`.
branch name:
    #!/usr/bin/env bash
    git fetch origin
    git checkout main
    git pull origin
    git checkout -b {{ name }}
    git push -u origin {{ name }}


# Run Terraform and Terragrunt formatting locally.
format:
    #!/usr/bin/env bash
    terraform fmt -recursive
    terragrunt hclfmt


# Check that the pre-existing runtime VPC and private subnets are available.
check-network vpc_name:
    #!/usr/bin/env bash
    set -euo pipefail

    configured_region=$(aws configure get region)
    configured_vpc_name={{vpc_name}}

    echo "Checking AWS network prerequisites..."
    echo "AWS CLI configured region: $configured_region"
    echo "VPC Name tag: $configured_vpc_name"

    vpc_ids_raw="$(
        aws ec2 describe-vpcs \
          --region "$configured_region" \
          --filters "Name=tag:Name,Values=$configured_vpc_name" \
          --query 'Vpcs[].VpcId' \
          --output text
    )"

    read -r -a vpc_ids <<< "$vpc_ids_raw"

    if [[ "${#vpc_ids[@]}" -eq 0 || -z "${vpc_ids[0]:-}" ]]; then
        echo "🔴 No VPC found with Name tag '$configured_vpc_name' in $configured_region."
        exit 1
    fi

    if [[ "${#vpc_ids[@]}" -gt 1 ]]; then
        echo "🔴 Multiple VPCs found with Name tag '$configured_vpc_name' in $configured_region: ${vpc_ids[*]}"
        echo "Update infra/live/global_vars.hcl so vpc_name uniquely identifies one VPC."
        exit 1
    fi

    vpc_id="${vpc_ids[0]}"

    public_subnet_ids_raw="$(
        aws ec2 describe-subnets \
          --region "$configured_region" \
          --filters "Name=vpc-id,Values=$vpc_id" "Name=tag:Name,Values=*public*" \
          --query 'Subnets[].SubnetId' \
          --output text
    )"

    private_subnet_ids_raw="$(
        aws ec2 describe-subnets \
          --region "$configured_region" \
          --filters "Name=vpc-id,Values=$vpc_id" "Name=tag:Name,Values=*private*" \
          --query 'Subnets[].SubnetId' \
          --output text
    )"

    read -r -a public_subnet_ids <<< "$public_subnet_ids_raw"
    read -r -a private_subnet_ids <<< "$private_subnet_ids_raw"

    if [[ "${#public_subnet_ids[@]}" -eq 0 || -z "${public_subnet_ids[0]:-}" ]]; then
        echo "🔴 No public subnets found in $vpc_id with Name tags containing 'public'."
        exit 1
    fi

    if [[ "${#private_subnet_ids[@]}" -eq 0 || -z "${private_subnet_ids[0]:-}" ]]; then
        echo "🔴 No private subnets found in $vpc_id with Name tags containing 'private'."
        exit 1
    fi

    echo "✅ Found VPC: $vpc_id"
    echo "✅ Found public subnets: ${public_subnet_ids[*]}"
    echo "✅ Found private subnets: ${private_subnet_ids[*]}"
    echo "✅ AWS network prerequisites are present."


# Run a Terragrunt operation for one environment/module pair.
tg env module op:
    #!/usr/bin/env bash
    set -euo pipefail
    cd {{justfile_directory()}}/infra/live/{{env}}/{{module}}
    if [[ -z "${AWS_ACCOUNT_ID:-}" ]]; then
        AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
        export AWS_ACCOUNT_ID
    fi
    terragrunt {{op}}


# Run a Terragrunt operation across all live stacks.
tg-all env op:
    #!/usr/bin/env bash
    set -euo pipefail
    cd {{justfile_directory()}}/infra/live/{{env}}
    if [[ -z "${AWS_ACCOUNT_ID:-}" ]]; then
        AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
        export AWS_ACCOUNT_ID
    fi
    export TF_VAR_lambda_version="this"
    export TF_VAR_image_uri="plan-placeholder"
    export TF_VAR_debug_uri="plan-placeholder"
    terragrunt run-all {{op}}


# Print the raw Terragrunt run-all dependency graph.
tg-graph env provider='aws':
    #!/usr/bin/env bash
    set -euo pipefail
    cd {{justfile_directory()}}/infra/live/{{env}}/{{provider}}
    if [[ -z "${AWS_ACCOUNT_ID:-}" ]]; then
        AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
        export AWS_ACCOUNT_ID
    fi

    terragrunt run-all graph-dependencies \
      --terragrunt-non-interactive \
      --terragrunt-include-external-dependencies \
      --terragrunt-log-level error
