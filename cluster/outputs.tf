output "id" {
  description = "The ID of the ECS cluster."
  value       = aws_ecs_cluster.main.id
}

output "execution_role_arn" {
  description = "The ARN of the execution IAM role for the ECS services."
  value       = aws_iam_role.main.arn
}

output "log_group_arn" {
  description = "The ARN of the CloudWatch log group."
  value       = try(aws_cloudwatch_log_group.main[0].arn, null)
}
