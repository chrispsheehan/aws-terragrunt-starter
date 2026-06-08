# `security`

Shared security-group module.

## Owns

- shared runtime security group

## Key outputs

- `runtime_sg`
- `ecs_sg`

Used by migrations and ECS service modules.

## Bootstrap Notes

Rules are defined with standalone `aws_vpc_security_group_ingress_rule` and `aws_vpc_security_group_egress_rule` resources rather than inline security-group blocks.

The shared runtime security group permits outbound traffic.
`ecs_sg` is kept as a compatibility alias for existing ECS consumers, while `runtime_sg` is the preferred generic output for cross-runtime reuse.
