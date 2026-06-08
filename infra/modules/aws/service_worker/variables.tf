### start of static vars set in root.hcl ###
variable "state_bucket" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "project_name" {
  type = string
}

variable "ecr_repository_name" {
  type = string
}
### end of static vars set in root.hcl ###

variable "service_name" {
  type    = string
  default = "ecs-worker"
}

variable "vpc_name" {
  type = string
}

variable "container_port" {
  type    = number
  default = 80
}

variable "local_tunnel" {
  type    = bool
  default = false
}

variable "wait_for_steady_state" {
  type    = bool
  default = false
}

variable "bootstrap" {
  type    = bool
  default = false
}

variable "ecs_security_group_id" {
  type = string
}

variable "task_definition_arn" {
  type    = string
  default = "arn:aws:ecs:eu-west-2:111111111111:task-definition/mock-task-worker:1"
}

variable "cluster_id" {
  type = string
}

variable "cluster_name" {
  type = string
}
