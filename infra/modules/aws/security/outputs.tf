output "ecs_sg" {
  value = aws_security_group.runtime.id
}

output "runtime_sg" {
  value = aws_security_group.runtime.id
}
