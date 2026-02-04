output "service_account_namespace" {
  value       = local.enabled ? var.service_account_namespace : null
  description = "Kubernetes Service Account namespace"
}

output "service_account_name" {
  value       = local.enabled ? var.service_account_name : null
  description = "Kubernetes Service Account name"
}

output "service_account_role_name" {
  value       = local.enabled ? aws_iam_role.service_account[0].name : null
  description = "IAM role name"
}

output "service_account_role_unique_id" {
  value       = local.enabled ? aws_iam_role.service_account[0].unique_id : null
  description = "IAM role unique ID"
}

output "service_account_role_arn" {
  value       = local.enabled ? aws_iam_role.service_account[0].arn : null
  description = "IAM role ARN"
}

output "service_account_policy_name" {
  value       = local.iam_policy_enabled ? aws_iam_policy.service_account[0].name : null
  description = "IAM policy name"
}

output "service_account_policy_id" {
  value       = local.iam_policy_enabled ? aws_iam_policy.service_account[0].id : null
  description = "IAM policy ID"
}

output "service_account_policy_arn" {
  value       = local.iam_policy_enabled ? aws_iam_policy.service_account[0].arn : null
  description = "IAM policy ARN"
}

output "authentication_mode" {
  value       = local.enabled ? var.authentication_mode : null
  description = "Authentication mode used: 'irsa' or 'pod_identity'"
}

output "pod_identity_association_arn" {
  value       = local.enabled && var.authentication_mode == "pod_identity" ? aws_eks_pod_identity_association.this[0].association_arn : null
  description = "ARN of the EKS Pod Identity association (only for pod_identity mode)"
}

output "pod_identity_association_id" {
  value       = local.enabled && var.authentication_mode == "pod_identity" ? aws_eks_pod_identity_association.this[0].association_id : null
  description = "ID of the EKS Pod Identity association (only for pod_identity mode)"
}

output "cross_account_role_arns" {
  value       = local.enabled ? var.cross_account_role_arns : []
  description = "List of cross-account role ARNs this role can assume"
  sensitive   = false
}

output "cross_account_external_id" {
  value       = local.enabled ? local.cross_account_external_id : null
  description = "External ID used for cross-account role assumption (null if not configured, auto-generated if 'auto' was specified)"
  sensitive   = true  # External ID should be treated as sensitive
}

output "cross_account_policy_name" {
  value       = local.cross_account_enabled ? aws_iam_role_policy.cross_account_assume_role[0].name : null
  description = "Name of the inline policy granting cross-account assume role permissions"
}

output "cross_account_enabled" {
  value       = local.cross_account_enabled
  description = "Whether cross-account role assumption is enabled for this role"
}
