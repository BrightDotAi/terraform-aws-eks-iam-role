variable "region" {
  type        = string
  description = "AWS Region"
  default     = "us-west-2"
}

variable "eks_cluster_name" {
  type        = string
  description = "Name of the EKS cluster for Pod Identity associations"
  default     = "my-cluster"
}

# Cross-Account Target Account IDs
variable "data_lake_account_id" {
  type        = string
  description = "AWS Account ID containing the data lake resources"
  default     = "111111111111" # Replace with actual account ID
}

variable "staging_account_id" {
  type        = string
  description = "AWS Account ID for staging environment"
  default     = "333333333333" # Replace with actual account ID
}

variable "production_account_id" {
  type        = string
  description = "AWS Account ID for production environment"
  default     = "444444444444" # Replace with actual account ID
}

variable "dev_account_id" {
  type        = string
  description = "AWS Account ID for development environment"
  default     = "555555555555" # Replace with actual account ID
}

# Local Resources
variable "local_data_bucket" {
  type        = string
  description = "S3 bucket name in local account for data analytics"
  default     = "my-analytics-data"
}

