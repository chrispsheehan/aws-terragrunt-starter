output "service_name" {
  value = aws_ecs_service.service_worker.name
}

output "cluster_name" {
  value = var.cluster_name
}

output "container_port" {
  value = var.container_port
}
