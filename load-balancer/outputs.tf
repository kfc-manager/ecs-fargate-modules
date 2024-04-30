output "target_groups" {
  description = "List of objects for created target groups accessible by the load balancer."
  value = [for index, value in var.target_groups : {
    arn               = aws_alb_target_group.main[index].arn
    lb_security_group = aws_security_group.main.id
  }]
}

output "dns_name" {
  description = "The DNS name of the load balancer."
  value       = aws_lb.main.dns_name
}

output "zone_id" {
  description = "The zone ID of the publicly hosted DNS zone of the load balancer."
  value       = aws_lb.main.zone_id
}
