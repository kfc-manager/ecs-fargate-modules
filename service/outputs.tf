output "dns_endpoint" {
  description = "The static private DNS endpoint under which the service is available."
  value       = var.dns_namespace != null ? "${var.identifier}.${var.dns_namespace}" : null
}

output "log_group_arn" {
  description = "The ARN of the CloudWatch log group."
  value       = try(aws_cloudwatch_log_group.main[0].arn, null)
}

output "security_group" {
  description = "The ID of the created security group for which to allow access to this service. Will be null if the service is assigned to a load balancer target group."
  value       = try(aws_security_group.export[0].id, null)
}
