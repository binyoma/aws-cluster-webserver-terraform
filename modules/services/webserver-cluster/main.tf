
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true
}

resource "aws_subnet" "subnet1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"
}

resource "aws_subnet" "subnet2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1b"
}
resource "aws_launch_template" "example" {
  image_id               = "ami-0fb653ca2d3203ac1"
  instance_type          = var.instance_type

  user_data = templatefile("${path.module}/user-data.sh",{
    server_port =var.server_port
    db_address  =data.terraform_remote_state.db.outputs.address
    db_port     =data.terraform_remote_state.db.outputs.port
  } )
}
resource "aws_security_group" "instance" {
  name = "${var.cluster_name}-instance"

  ingress {
    from_port = var.server_port
    to_port = var.server_port
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_autoscaling_group" "example" {

  vpc_zone_identifier = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]
  target_group_arns = [aws_lb_target_group.asg.arn]
  health_check_type = "ELB"

  max_size = var.max_size
  min_size = var.min_size

  launch_template {
    id      = aws_launch_template.example.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    propagate_at_launch = true
    value               = "${var.cluster_name}"
  }
}

resource "aws_lb" "example" {
  name = "${var.cluster_name}-example"
  load_balancer_type = "application"
  subnets = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]
  security_groups = [aws_security_group.alb.id]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.example.arn
  port              = local.http_port
  protocol          = "HTTP"

  #By default, return a simple 404 page
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code = "404"
    }
  }
}

resource "aws_security_group" "alb" {
  name = "${var.cluster_name}-alb"
}

resource "aws_security_group_rule" "allow_http_inbound" {
  from_port         = local.http_port
  protocol          = local.tcp_protocol
  security_group_id = aws_security_group.alb.id
  to_port           = local.http_port
  type              = "ingress"
  cidr_blocks = local.all_ips
}

resource "aws_security_group_rule" "allow_all_outbound" {
  from_port         = local.any_port
  protocol          = local.any_protocol
  security_group_id = aws_security_group.alb.id
  to_port           = local.any_port
  type              = "egress"
  cidr_blocks = local.all_ips
}

resource "aws_lb_target_group" "asg" {
  name = "${var.cluster_name}"
  port = var.server_port
  protocol = "HTTP"
  vpc_id = aws_vpc.main.id

  health_check {
    path = "/"
    protocol = "HTTP"
    matcher = "200"
    interval = 15
    timeout = 3
    healthy_threshold = 2
    unhealthy_threshold = 2
  }
}
resource "aws_lb_listener_rule" "asg" {
  listener_arn = aws_lb_listener.http.arn
  priority = 100

  condition {
    path_pattern {
      values = ["*"]
    }
  }
  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.asg.arn
  }
}

data "terraform_remote_state" "db" {
  backend = "s3"

  config = {
    bucket = var.db_remote_state_bucket
    key    =var.db_remote_state_key
    region ="us-east-1"
    endpoints                   = {
      s3 = "http://s3.localhost.localstack.cloud:4566"
    }
    force_path_style            = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
    access_key                  = "test"
    secret_key                  = "test"
  }
}
locals {
  http_port   =80
  any_port    =0
  any_protocol="-1"
  tcp_protocol="tcp"
  all_ips     =["0.0.0.0/0"]
}
