################################
# IAM Role                     #
################################

data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "main" {
  name               = "${var.identifier}-RoleForFargateTask"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "main" {
  count      = length(var.policies)
  role       = aws_iam_role.main.name
  policy_arn = var.policies[count.index]
}

################################
# Security Groups              #
################################

resource "aws_security_group" "main" {
  name        = "${var.identifier}-SGForECSService"
  description = "Allows all egress and ingress for either a load balancer or services which assume the exported SG to the service holding this SG."
  vpc_id      = var.vpc_id

  tags = var.tags
}

# will allow the Fargate Tasks access to the internet and most importantly to pull it's image from the ECR repository
resource "aws_vpc_security_group_egress_rule" "main" {
  security_group_id = aws_security_group.main.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = -1
}

resource "aws_vpc_security_group_ingress_rule" "lb" {
  count                        = var.target_group != null ? 1 : 0
  security_group_id            = aws_security_group.main.id
  from_port                    = var.container_port
  to_port                      = var.container_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = var.target_group["lb_security_group"]
}

# this security group will be exported from the module, the security group will be
# given to services which shall access the service defined in this module
resource "aws_security_group" "export" {
  count       = var.target_group != null ? 0 : 1
  name        = "${var.identifier}-SGForOtherECSService"
  description = "Allows ingress to a service for other services to assume."
  vpc_id      = var.vpc_id

  tags = var.tags
}

resource "aws_vpc_security_group_ingress_rule" "sg" {
  count             = var.target_group != null ? 0 : 1
  security_group_id = aws_security_group.main.id
  from_port         = var.container_port
  to_port           = var.container_port
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
  #referenced_security_group_id = aws_security_group.export[0].id
}

resource "aws_vpc_security_group_egress_rule" "export" {
  count             = var.target_group != null ? 0 : 1
  security_group_id = aws_security_group.export[0].id
  from_port         = var.container_port
  to_port           = var.container_port
  ip_protocol       = "tcp"
  #referenced_security_group_id = aws_security_group.main.id
  cidr_ipv4 = "0.0.0.0/0"
}

################################
# ECR Repository               #
################################

resource "aws_ecr_repository" "main" {
  count                = var.image == null ? 1 : 0
  name                 = var.identifier
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  tags = var.tags
}

################################
# CloudWatch                   #
################################

resource "aws_cloudwatch_log_group" "main" {
  count             = var.log_config != null ? 1 : 0
  name              = var.identifier
  retention_in_days = var.log_config["retention_in_days"]

  tags = var.tags
}

################################
# ECS Service                  #
################################

# TODO look into placement_constraints
resource "aws_ecs_task_definition" "main" {
  family                   = var.identifier
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = aws_iam_role.main.arn
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory

  container_definitions = jsonencode([
    {
      name        = var.identifier
      image       = var.image == null ? aws_ecr_repository.main[0].repository_url : var.image["uri"]
      environment = [for key, value in var.env_variables : { name = key, value = value }]
      portMappings = [{
        protocol      = "tcp"
        containerPort = var.container_port
        hostPort      = var.container_port
      }]
      logConfiguration = var.log_config != null ? {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.main[0].id
          awslogs-region        = var.region
          awslogs-stream-prefix = "service"
        }
      } : null
    }
  ])

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = var.cpu_architecture
  }

  tags = var.tags
}

resource "aws_service_discovery_private_dns_namespace" "main" {
  count = var.dns_namespace != null ? 1 : 0
  name  = var.dns_namespace
  vpc   = var.vpc_id

  tags = var.tags
}

resource "aws_service_discovery_service" "main" {
  count = var.dns_namespace != null ? 1 : 0
  name  = var.identifier

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main[0].id

    dns_records {
      ttl  = 3600
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }

  tags = var.tags
}

resource "aws_ecs_service" "main" {
  name                 = var.identifier
  cluster              = var.cluster_id
  task_definition      = aws_ecs_task_definition.main.arn
  launch_type          = "FARGATE"
  desired_count        = var.task_count
  force_new_deployment = true

  network_configuration {
    subnets          = var.subnets
    assign_public_ip = var.public_ip
    security_groups  = concat([aws_security_group.main.id], var.security_groups)
  }

  dynamic "load_balancer" {
    for_each = var.target_group != null ? [1] : []

    content {
      target_group_arn = var.target_group["arn"]
      container_name   = var.identifier
      container_port   = var.container_port
    }
  }

  dynamic "service_registries" {
    for_each = var.dns_namespace != null ? [1] : []
    content {
      registry_arn = aws_service_discovery_service.main[0].arn
    }
  }

  tags = var.tags
}

################################
# Auto Scaling                 #
################################

resource "aws_appautoscaling_target" "main" {
  count              = var.autoscaling != null ? 1 : 0
  max_capacity       = var.autoscaling["max_count"]
  min_capacity       = var.autoscaling["min_count"]
  resource_id        = "service/${var.cluster_id}/${var.identifier}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  tags = var.tags
}

resource "aws_appautoscaling_policy" "memory" {
  count              = var.autoscaling != null ? 1 : 0
  name               = "${var.identifier}-memory-based-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.main[0].resource_id
  scalable_dimension = aws_appautoscaling_target.main[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.main[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }

    target_value = var.autoscaling["memory_target_utilization"]
  }
}

resource "aws_appautoscaling_policy" "cpu" {
  count              = var.autoscaling != null ? 1 : 0
  name               = "${var.identifier}-cpu-based-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.main[0].resource_id
  scalable_dimension = aws_appautoscaling_target.main[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.main[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value = var.autoscaling["cpu_target_utilization"]
  }
}

