# List root recipes plus split CI/deploy recipe files.
_default:
    @just --list
    @printf '\nCI recipes (`just --justfile justfile.ci --list`):\n'
    @just --justfile justfile.ci --list
    @printf '\nDeploy recipes (`just --justfile justfile.deploy --list`):\n'
    @just --justfile justfile.deploy --list
    @printf '\nDestroy recipes (`just --justfile justfile.destroy --list`):\n'
    @just --justfile justfile.destroy --list


PROJECT_DIR := justfile_directory()
LAMBDA_DIR := "lambdas"
CONTAINERS_DIR := "containers"
APPSPEC_DIR := "appspec"


# Return the Lambda artifact directory name.
code-bucket-get-lambda-artifact-dir:
    @echo {{LAMBDA_DIR}}


# Return the AppSpec artifact directory name.
code-bucket-get-appspec-artifact-dir:
    @echo {{APPSPEC_DIR}}


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


# Open an ECS Exec shell in the worker service container.
worker-debug-shell env service_name='ecs-worker' container_name='ecs-worker' command='/bin/sh':
    #!/usr/bin/env bash
    set -euo pipefail

    if ! command -v session-manager-plugin >/dev/null 2>&1; then
        echo "session-manager-plugin is not installed or not on PATH."
        exit 1
    fi

    aws_region="${AWS_REGION:-eu-west-2}"
    project_name="$(basename "{{PROJECT_DIR}}")"
    cluster_name="{{env}}-${project_name}-cluster"

    task_arn="$(
        aws ecs list-tasks \
          --region "$aws_region" \
          --cluster "$cluster_name" \
          --service-name "{{service_name}}" \
          --desired-status RUNNING \
          --query 'taskArns[0]' \
          --output text
    )"

    if [[ -z "$task_arn" || "$task_arn" == "None" ]]; then
        echo "No running task found for service {{service_name}} in cluster ${cluster_name}."
        exit 1
    fi

    echo "Opening ECS Exec shell to {{container_name}} in {{service_name}}..."
    aws ecs execute-command \
      --region "$aws_region" \
      --cluster "$cluster_name" \
      --task "$task_arn" \
      --container "{{container_name}}" \
      --interactive \
      --command "{{command}}"


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


# Run tg-graph once locally and feed the raw output through the CI graph and
# wave processors.
tg-graph-waves env provider='aws':
    #!/usr/bin/env bash
    set -euo pipefail
    cd {{justfile_directory()}}

    tg_graph_json="$(
      TG_GRAPH_OUTPUT="$(just tg-graph "{{env}}" "{{provider}}")" \
        just --justfile "{{justfile_directory()}}/justfile.ci" tg-graph-output-to-json "{{env}}" "{{provider}}"
    )"

    TG_GRAPH_JSON="$tg_graph_json" \
      just --justfile "{{justfile_directory()}}/justfile.ci" tg-graph-json-to-waves
