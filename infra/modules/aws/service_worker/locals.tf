locals {
  selected_task_definition_arn = var.bootstrap ? aws_ecs_task_definition.bootstrap[0].arn : var.task_definition_arn
  bootstrap_ecr_repository_arn = "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/${var.ecr_repository_name}"
  bootstrap_image_uri          = var.bootstrap ? data.aws_ecr_image.bootstrap[0].image_uri : ""
  bootstrap_container_definitions = jsonencode([{
    name  = var.service_name
    image = local.bootstrap_image_uri

    command = [
      "sh",
      "-c",
      "printf 'ok\\n' > /usr/share/nginx/html/health && exec nginx -g 'daemon off;'",
    ]

    portMappings = [
      {
        name          = "${var.service_name}-${var.container_port}-tcp"
        containerPort = var.container_port
        hostPort      = var.container_port
        protocol      = "tcp"
        appProtocol   = "http"
      }
    ]

    essential = true
  }])
}
