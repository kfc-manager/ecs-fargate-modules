variable "identifier" {
  description = "The unique identifier to differentiate resources."
  type        = string
  validation {
    condition     = length(var.identifier) > 2
    error_message = "Identifier must be at least 3 characters"
  }
}

variable "cluster_id" {
  description = "The ID of the ECS cluster."
  type        = string
}

variable "region" {
  description = "The region in which the service is deployed."
  type        = string
}

variable "cpu_architecture" {
  description = "The architecture of the CPU. Valid values are: 'X86_64' and 'ARM64'."
  type        = string
  default     = "X86_64"
  validation {
    condition     = var.cpu_architecture == "X86_64" || var.cpu_architecture == "ARM64"
    error_message = "CPU architecture must be 'X86_64' or 'ARM64'"
  }
}

variable "dns_namespace" {
  description = "The DNS namespace under which the service is available."
  type        = string
  default     = null
}

variable "vpc_id" {
  description = "The ID of the VPC in which the cluster is placed."
  type        = string
}

variable "execution_role_arn" {
  description = "The ARN of the execution IAM role for the ECS service."
  type        = string
}

variable "policies" {
  description = "A list of IAM policy ARNs for the task's IAM role."
  type        = list(string)
  default     = []
}

variable "container_port" {
  description = "The port on which the containers will be exposed."
  type        = number
}

variable "subnets" {
  description = "List of IDs of the subnets in which the Fargate tasks will be deployed."
  type        = list(string)
}

variable "security_groups" {
  description = "List of security group IDs the Fargate tasks will hold."
  type        = list(string)
  default     = []
}

variable "public_ip" {
  description = "A flag for wether or not assigning a public IP address to the containers."
  type        = bool
  default     = false
}

variable "target_group" {
  description = "Object to define target group for the service to join. Only needed if the service needs to be exposed publicly by a load balancer."
  type = object({
    arn               = string
    lb_security_group = string
  })
  default = null
}

variable "autoscaling" {
  description = "Object to define the auto scaling behavior of the Fargate tasks inside the service."
  type = object({
    max_count                 = number
    min_count                 = number
    cpu_target_utilization    = optional(number, 50)
    memory_target_utilization = optional(number, 50)
  })
  default = null
}

# this needs to be wrapped by an object to perform the null check in terraform plan,
# since we create conditionally an ECR repository and otherwise it is not clear to
# terraform if this will be null or not in the planning stage
variable "image" {
  description = "Object of the image which will be pulled by the container definition of the Fargate tasks."
  type = object({
    uri = string
  })
  default = null
}

variable "log_config" {
  description = "Object to define logging configuration for the container in the Fargate task to CloudWatch."
  type = object({
    retention_in_days = number
  })
  default = null
  validation {
    condition = try(var.log_config["retention_in_days"], 1) == 1 || (
      try(var.log_config["retention_in_days"], 3) == 3) || (
      try(var.log_config["retention_in_days"], 5) == 5) || (
      try(var.log_config["retention_in_days"], 7) == 7) || (
      try(var.log_config["retention_in_days"], 14) == 14) || (
      try(var.log_config["retention_in_days"], 30) == 30) || (
      try(var.log_config["retention_in_days"], 365) == 365) || (
    try(var.log_config["retention_in_days"], 0) == 0)
    error_message = "Retention in days must be one of these values: 0, 1, 3, 5, 7, 14, 30, 365"
  }
}

variable "task_count" {
  description = "Desired number of Fargate task replicas running under the service."
  type        = number
  default     = 1
}

variable "task_cpu" {
  description = "Number of virtual CPU units assigned to each Fargate task."
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Amount of memory in MiB assigned to each Fargate task."
  type        = number
  default     = 512
}

variable "env_variables" {
  description = "A map of environment variables for the Fargate task initialized at runtime."
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "A map of tags to add to all resources."
  type        = map(string)
  default     = {}
}
