module "bootstrap_task" {
  count = var.bootstrap ? 1 : 0

  source = "../_shared/task_bootstrap"

  aws_region          = var.aws_region
  project_name        = var.project_name
  ecr_repository_name = var.ecr_repository_name
}

resource "aws_ecs_service" "service_worker" {
  name            = var.service_name
  cluster         = var.cluster_id
  task_definition = local.selected_task_definition_arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.public.ids
    assign_public_ip = var.bootstrap ? true : false
    security_groups  = [var.ecs_security_group_id]
  }

  enable_execute_command = var.local_tunnel
  wait_for_steady_state  = var.wait_for_steady_state

  deployment_circuit_breaker {
    enable   = false
    rollback = false
  }

  deployment_controller {
    type = "ECS"
  }

  lifecycle {
    precondition {
      condition     = length(data.aws_subnets.public.ids) > 0
      error_message = "Selected ECS service subnet list must not be empty."
    }

    ignore_changes = [
      task_definition,
    ]
  }
}
