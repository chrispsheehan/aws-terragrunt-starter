locals {
  selected_task_definition_arn = var.bootstrap ? module.bootstrap_task[0].task_definition_arn : var.task_definition_arn
}
