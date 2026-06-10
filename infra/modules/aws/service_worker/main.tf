resource "aws_iam_role" "bootstrap_execution" {
  count = var.bootstrap ? 1 : 0

  name               = "${var.service_name}-bootstrap-ecs-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.bootstrap_assume_role.json
}

resource "aws_iam_role" "bootstrap_task" {
  count = var.bootstrap ? 1 : 0

  name               = "${var.service_name}-bootstrap-ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.bootstrap_assume_role.json
}

resource "aws_iam_role_policy_attachment" "bootstrap_execution" {
  count = var.bootstrap ? 1 : 0

  role       = aws_iam_role.bootstrap_execution[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_task_definition" "bootstrap" {
  count = var.bootstrap ? 1 : 0

  family                   = "${var.service_name}-bootstrap-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.bootstrap_execution[0].arn
  task_role_arn            = aws_iam_role.bootstrap_task[0].arn

  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }

  container_definitions = local.bootstrap_container_definitions
}

resource "aws_ecs_service" "service_worker" {
  name            = var.service_name
  cluster         = var.cluster_id
  task_definition = local.selected_task_definition_arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.public.ids
    assign_public_ip = false
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
