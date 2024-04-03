data "aws_ami" "amazon-linux" {
  most_recent = true
  owners      = ["amazon"]
  name_regex  = "al2023-ami-minimal.*"

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

data "aws_subnet" "subnets" {
  count = length(var.elb_subnets)
  id    = var.elb_subnets[count.index]
}

