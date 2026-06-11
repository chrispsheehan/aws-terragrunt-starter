output "task_definition_arn" {
  value = module.task_bootstrap.task_definition_arn
}

output "cloudwatch_log_group" {
  value = module.task_bootstrap.cloudwatch_log_group
}

output "root_path" {
  value = module.task_bootstrap.root_path
}

output "service_name" {
  value = module.task_bootstrap.service_name
}
