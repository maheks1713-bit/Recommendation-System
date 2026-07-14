variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix used for naming all resources"
  type        = string
  default     = "smartpicks"
}

variable "environment" {
  description = "Deployment environment (e.g. staging, prod)"
  type        = string
  default     = "staging"
}

# IMPORTANT: AWS Academy Learner Lab does not allow creating IAM roles/policies.
# LabRole is a pre-existing role provisioned by Academy with broad permissions.
# We pass its ARN in rather than creating a new role, to stay within lab constraints.
variable "lab_role_arn" {
  description = "ARN of the pre-existing AWS Academy LabRole used by all Lambda functions"
  type        = string
}

variable "api_key" {
  description = "Shared secret clients must send as the x-api-key header on every API request"
  type        = string
  sensitive   = true
}

variable "alert_email" {
  description = "Email address subscribed to the CloudWatch alarm SNS topic"
  type        = string
  default     = "maheks1713@gmail.com"
}
