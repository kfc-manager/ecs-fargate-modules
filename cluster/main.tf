resource "aws_cloudwatch_log_group" "main" {
  count             = var.log_config != null ? 1 : 0
  name              = var.identifier
  retention_in_days = var.log_config["retention_in_days"]

  tags = var.tags
}

resource "aws_ecs_cluster" "main" {
  name = var.identifier

  dynamic "configuration" {
    for_each = var.log_config != null ? [1] : []
    content {
      execute_command_configuration {
        logging = "OVERRIDE"

        log_configuration {
          cloud_watch_log_group_name = aws_cloudwatch_log_group.main[0].name
        }
      }
    }
  }

  tags = var.tags
}

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
  name               = "${var.identifier}-ExecutionRoleForTasks"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "main" {
  role       = aws_iam_role.main.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
