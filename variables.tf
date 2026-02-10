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

variable "target_role_arns" {
  type        = map(string)
  description = <<-EOT
    Map of service account identifiers to their target role ARN (1:1 relationship).

    Keys: Format "{namespace}:{service_account_name}"
    - For Pod Identity mode: Must be valid Kubernetes names (no wildcards)
    - For IRSA mode: Can include patterns like "pr-*:app" (existing behavior)

    Values: Target IAM role ARNs (same-account or cross-account)

    ServiceAccounts defined here get both primary AND target role Pod Identity associations.
    For ServiceAccounts that only need primary role access, use the existing
    service_account_* variables instead.

    Example:
    {
      "analytics:data-processor"     = "arn:aws:iam::111111111111:role/DataLakeAccess"
      "ml:model-trainer"             = "arn:aws:iam::222222222222:role/MLModelsAccess"
      "monitoring:metrics-collector" = "arn:aws:iam::333333333333:role/MetricsAccess"
    }
    EOT
  default     = {}

  validation {
    condition = alltrue([
      for sa_key in keys(var.target_role_arns) :
      can(regex("^.+:.+$", sa_key)) && length(split(":", sa_key)) == 2
    ])
    error_message = "All target_role_arns keys must be in format 'namespace:service-account-name'."
  }

  validation {
    condition = alltrue([
      for target_arn in values(var.target_role_arns) :
      can(regex("^arn:aws:iam::[0-9]{12}:role/.+", target_arn))
    ])
    error_message = "All target role ARNs must be valid IAM role ARNs with format 'arn:aws:iam::ACCOUNT-ID:role/ROLE-NAME'."
  }
}

