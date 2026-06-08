resource "aws_security_group" "runtime" {
  name        = local.runtime_sg_name
  description = "Security group for shared application runtimes"
  vpc_id      = data.aws_vpc.this.id
}

resource "aws_vpc_security_group_egress_rule" "runtime_to_internet" {
  security_group_id = aws_security_group.runtime.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Allow shared application runtime outbound traffic"
}
