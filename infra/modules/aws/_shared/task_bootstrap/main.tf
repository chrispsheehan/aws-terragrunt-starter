module "task_bootstrap" {
  source = "../task"

  project_name        = var.project_name
  ecr_repository_name = var.ecr_repository_name
  aws_region          = var.aws_region
  container_port      = 80
  cpu                 = 256
  memory              = 512

  image_uri = local.bootstrap_image_uri

  root_path    = ""
  service_name = "ecs-bootstrap"
  command = [
    "sh",
    "-c",
    "printf 'ok\\n' > /usr/share/nginx/html/health && exec nginx -g 'daemon off;'",
  ]
}
