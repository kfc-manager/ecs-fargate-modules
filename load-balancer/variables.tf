variable "identifier" {
  description = "The unique identifier to differentiate resources."
  type        = string
  validation {
    condition     = length(var.identifier) > 2
    error_message = "Identifier must be at least 3 characters"
  }
}

variable "vpc_id" {
  description = "The ID of the VPC in which the load balancer will be deployed."
  type        = string
}

variable "subnets" {
  description = "List of IDs of the subnets in which the load balancer will be deployed."
  type        = list(string)
}

variable "target_groups" {
  description = "List of objects to define target groups served by the load balancer."
  type = list(object({
    name              = string
    host_domain       = string
    certificate_arn   = string
    health_check_path = optional(string, "/")
  }))
  validation {
    condition     = length(var.target_groups) > 0
    error_message = "Target group list must contain at least one element"
  }
}

variable "tags" {
  description = "A map of tags to add to all resources."
  type        = map(string)
  default     = {}
}
