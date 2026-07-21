# `security`

Shared security-group module.

## Owns

- shared runtime security group

## Key outputs

- `runtime_sg`

## Bootstrap Notes

Rules are defined with standalone `aws_vpc_security_group_ingress_rule` and `aws_vpc_security_group_egress_rule` resources rather than inline security-group blocks.

The shared runtime security group permits outbound traffic.
