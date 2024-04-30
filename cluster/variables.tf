variable "identifier" {
  description = "The unique identifier to differentiate resources."
  type        = string
  validation {
    condition     = length(var.identifier) > 2
    error_message = "Identifier must be at least 3 characters"
  }
}

variable "log_config" {
  description = "Object to define logging configuration for the ECS cluster managemenet to CloudWatch."
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

variable "tags" {
  description = "A map of tags to add to all resources."
  type        = map(string)
  default     = {}
}
