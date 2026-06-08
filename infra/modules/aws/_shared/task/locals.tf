locals {
  cloudwatch_log_name = "/ecs/${var.service_name}"
  image_uri           = var.image_uri
  debug_uri           = var.debug_uri
  ecr_repository_arn  = "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/${var.ecr_repository_name}"
  root_path_prefix    = var.root_path != "" ? "/${var.root_path}" : ""

  shared_environment = [
    {
      name  = "AWS_REGION"
      value = "${var.aws_region}"
    },
    {
      name  = "AWS_SERVICE_NAME"
      value = "${var.service_name}"
    },
    {
      name  = "IMAGE"
      value = "${local.image_uri}"
    },
    {
      name  = "XRAY_ENABLED"
      value = tostring(var.xray_enabled)
    },
    {
      name  = "ROOT_PATH"
      value = local.root_path_prefix
    },
  ]

  base_containers = [
    local.svc-container
  ]

  debug_sidecar = var.local_tunnel ? [local.debug-container] : []

  container_definitions = concat(
    local.base_containers,
    local.debug_sidecar
  )

  svc-container = merge(
    {
      name  = var.service_name
      image = local.image_uri

      portMappings = [
        {
          name          = "${var.service_name}-${var.container_port}-tcp"
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
          appProtocol   = "http"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "${local.cloudwatch_log_name}"
          "awslogs-region"        = "${var.aws_region}"
          "awslogs-stream-prefix" = "ecs"
        }
      }

      essential   = true
      environment = concat(local.shared_environment, var.additional_env_vars)
    },
    var.health_check == null ? {} : {
      healthCheck = {
        command     = var.health_check.command
        interval    = var.health_check.interval
        timeout     = var.health_check.timeout
        retries     = var.health_check.retries
        startPeriod = var.health_check.start_period
      }
    },
    var.command == null ? {} : {
      command = var.command
    }
  )

  debug-container = {
    name  = "${var.service_name}-debug"
    image = local.debug_uri

    command = ["sleep", "infinity"]

    essential   = false
    environment = concat(local.shared_environment, var.additional_env_vars)
  }
}
