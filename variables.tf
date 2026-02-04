variable "service_account_name" {
  type        = string
  description = <<-EOT
    Kubernetes ServiceAccount name.
    Leave empty or set to "*" to indicate all Service Accounts, or if using `service_account_namespace_name_list`.
    EOT
  default     = null
}

variable "service_account_namespace" {
  type        = string
  description = <<-EOT
    Kubernetes Namespace where service account is deployed. Leave empty or set to "*" to indicate all Namespaces,
    or if using `service_account_namespace_name_list`.
    EOT
  default     = null
}

variable "service_account_namespace_name_list" {
  type        = list(string)
  description = <<-EOT
    List of `namespace:name` for service account assume role IAM policy if you need more than one. May include wildcards.
    EOT
  default     = []
}

variable "aws_account_number" {
  type        = string
  default     = null
  description = "AWS account number of EKS cluster owner. If an AWS account number is not provided, the current aws provider account number will be used."
}

variable "aws_partition" {
  type        = string
  default     = "aws"
  description = "AWS partition: 'aws', 'aws-cn', or 'aws-us-gov'"
}

variable "aws_iam_policy_document" {
  type        = any
  default     = []
  description = <<-EOT
    JSON string representation of the IAM policy for this service account as list of string (0 or 1 items).
    If empty, no custom IAM policy document will be used. If the list contains a single document, a custom
    IAM policy will be created and attached to the IAM role.
    Can also be a plain string, but that use is DEPRECATED because of Terraform issues.
    EOT
}

variable "eks_cluster_oidc_issuer_url" {
  type        = string
  description = "OIDC issuer URL for the EKS cluster (initial \"https://\" may be omitted). Required for 'irsa' authentication mode, optional for 'pod_identity' mode."
  default     = null
}

variable "permissions_boundary" {
  type        = string
  description = "ARN of the policy that is used to set the permissions boundary for the role."
  default     = null
}

variable "managed_policy_arns" {
  type        = set(string)
  description = "List of managed policies to attach to created role"
  default     = []
}

variable "authentication_mode" {
  type        = string
  description = <<-EOT
    Authentication mode for the IAM role. Valid values are:
    - 'irsa': Use IAM Roles for Service Accounts (OIDC-based, default for backward compatibility)
    - 'pod_identity': Use EKS Pod Identity (simpler, recommended for new deployments)
    EOT
  default     = "irsa"

  validation {
    condition     = contains(["irsa", "pod_identity"], var.authentication_mode)
    error_message = "The authentication_mode must be either 'irsa' or 'pod_identity'."
  }
}

variable "eks_cluster_name" {
  type        = string
  description = "EKS cluster name. Required when using 'pod_identity' authentication mode to create the Pod Identity association."
  default     = null
}

variable "cross_account_role_arns" {
  type        = list(string)
  description = <<-EOT
    List of cross-account IAM role ARNs that this role should be able to assume. 
    Each ARN must be from a different AWS account than the current one.
    Used for cross-account access patterns where EKS pods need to access resources in other accounts.
    
    Example: ["arn:aws:iam::111111111111:role/CrossAccountDataAccess", "arn:aws:iam::222222222222:role/CrossAccountS3Access"]
    EOT
  default     = []

  validation {
    condition = alltrue([
      for arn in var.cross_account_role_arns :
      can(regex("^arn:aws:iam::[0-9]{12}:role/.+", arn))
    ])
    error_message = "All cross_account_role_arns must be valid IAM role ARNs with format 'arn:aws:iam::ACCOUNT-ID:role/ROLE-NAME'."
  }
}

variable "cross_account_external_id" {
  type        = string
  description = <<-EOT
    External ID for cross-account role assumption security. Controls the sts:ExternalId condition in the assume role policy.
    
    Options:
    - null: No external ID required (default, appropriate for trusted environments)
    - "auto": Auto-generate a random external ID for enhanced security
    - "<custom-id>": Use your specific external ID (recommended for production)
    - "" (empty string): Will cause validation error - use one of the above options
    
    Note: If using external ID, the target cross-account roles must also require the same external ID.
    EOT
  default     = null

  validation {
    condition     = var.cross_account_external_id != ""
    error_message = "cross_account_external_id cannot be empty string. Use null (no external ID), \"auto\" (auto-generate), or provide a specific external ID."
  }
}
