module "task_worker" {
  source = "..//_shared//task"

  project_name        = var.project_name
  ecr_repository_name = var.ecr_repository_name
  aws_region          = var.aws_region
  container_port      = var.container_port
  cpu                 = var.cpu
  memory              = var.memory

  image_uri = var.image_uri
  debug_uri = var.debug_uri

  local_tunnel = var.local_tunnel
  xray_enabled = var.xray_enabled

  additional_env_vars = [
    {
      name  = "HEARTBEAT_FILE"
      value = "/tmp/worker-heartbeat"
    }
  ]

  health_check = {
    command      = ["CMD-SHELL", "python -c \"import os, time; path=os.environ['HEARTBEAT_FILE']; now=time.time(); mtime=os.path.getmtime(path); raise SystemExit(0 if now - mtime < 180 else 1)\""]
    interval     = 60
    timeout      = 5
    retries      = 3
    start_period = 30
  }

  root_path    = ""
  service_name = "ecs-worker"
  command      = ["python", "-u", "app.py"]
}
