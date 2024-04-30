################################
# Security Group               #
################################

resource "aws_security_group" "main" {
  name        = "${var.identifier}-SGForLoadBalancer"
  description = "Allows all egress and HTTP/HTTPS ingress to the load balancer."
  vpc_id      = var.vpc_id

  tags = var.tags
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.main.id
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "https" {
  security_group_id = aws_security_group.main.id
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "main" {
  security_group_id = aws_security_group.main.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = -1
}

################################
# Load Balancer                #
################################

resource "aws_lb" "main" {
  name               = var.identifier
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.main.id]
  subnets            = var.subnets
  idle_timeout       = 600

  enable_deletion_protection       = false
  enable_cross_zone_load_balancing = true

  tags = var.tags
}

################################
# Load Balancer Listeners      #
################################

resource "aws_alb_target_group" "main" {
  count       = length(var.target_groups)
  name        = var.target_groups[count.index]["name"]
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    healthy_threshold   = 3
    interval            = 30
    protocol            = "HTTP"
    matcher             = "200"
    timeout             = 3
    path                = var.target_groups[count.index]["health_check_path"]
    unhealthy_threshold = 2
  }

  tags = var.tags
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.id
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = 443
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = var.tags
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.id
  port              = 443
  protocol          = "HTTPS"

  ssl_policy      = "ELBSecurityPolicy-2016-08"
  certificate_arn = var.target_groups[length(var.target_groups) - 1]["certificate_arn"]

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.main[length(var.target_groups) - 1].arn
  }

  tags = var.tags
}

# add certificate to serve host domains of target groups under HTTPS
resource "aws_lb_listener_certificate" "https" {
  count           = length(var.target_groups) <= 1 ? 0 : length(var.target_groups) - 1
  listener_arn    = aws_lb_listener.https.arn
  certificate_arn = var.target_groups[count.index]["certificate_arn"]
}

# the first target group has the highest priority and it will descend from that on, the last target 
# group doesn't need a listener rule since it will be handled by the default action of the listener
resource "aws_lb_listener_rule" "https" {
  count        = length(var.target_groups) <= 1 ? 0 : length(var.target_groups) - 1
  listener_arn = aws_lb_listener.https.arn
  priority     = 100 - count.index

  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.main[count.index].arn
  }

  condition {
    host_header {
      values = [var.target_groups[count.index]["host_domain"]]
    }
  }

  tags = var.tags
}
