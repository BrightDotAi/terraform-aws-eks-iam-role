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

output "pod_identity_association_arns" {
  value = local.enabled && var.authentication_mode == "pod_identity" ? concat(
    [for assoc in aws_eks_pod_identity_association.primary : assoc.association_arn],
    [for assoc in aws_eks_pod_identity_association.target : assoc.association_arn]
  ) : []
  description = "List of all EKS Pod Identity association ARNs (primary + target roles)"
}

output "pod_identity_associations" {
  value = local.enabled && var.authentication_mode == "pod_identity" ? {
    primary = {
      for sa_name, assoc in aws_eks_pod_identity_association.primary :
      sa_name => {
        association_arn = assoc.association_arn
        association_id  = assoc.association_id
        namespace       = assoc.namespace
      }
    }
    target = {
      for sa_name, assoc in aws_eks_pod_identity_association.target :
      sa_name => {
        association_arn = assoc.association_arn
        association_id  = assoc.association_id
        namespace       = assoc.namespace
        target_role_arn = assoc.target_role_arn
      }
    }
  } : { primary = {}, target = {} }
  description = "Pod Identity associations for primary role access and target role access"
}

output "target_role_arns" {
  value       = local.enabled ? var.target_role_arns : {}
  description = "Map of target role ARNs this role can assume when using pod identities (includes both same-account and cross-account)"
  sensitive   = false
}

output "cross_account_target_arns" {
  value       = local.enabled ? local.cross_account_target_arns : []
  description = "List of cross-account target role ARNs when using pod identities (subset of target_role_arns)"
  sensitive   = false
}

output "same_account_target_arns" {
  value       = local.enabled ? local.same_account_target_arns : []
  description = "List of same-account target role ARNs when using pod identities (subset of target_role_arns)"
  sensitive   = false
}

output "target_roles_enabled" {
  value       = local.target_roles_enabled
  description = "Whether target role assumption is enabled for this role when using pod identities (includes both same-account and cross-account)"
}

output "cross_account_enabled" {
  value       = local.enabled && length(local.cross_account_target_arns) > 0
  description = "Whether cross-account target role assumption is enabled for this role when using pod identities"
}

output "service_accounts" {
  value = local.enabled ? {
    for sa_name, sa_config in local.service_accounts_map :
    sa_name => {
      namespace            = sa_config.namespace
      service_account_name = sa_config.service_account_name
      has_target_role      = sa_config.has_target_role
      target_role_arn      = sa_config.target_role_arn
      definition_source    = sa_config.has_target_role ? "target_role_arns" : "traditional_variables"
      authentication_mode  = var.authentication_mode
      # Add Pod Identity association info if available
      pod_identity_association_arn = var.authentication_mode == "pod_identity" ? (
        sa_config.namespace == var.service_account_namespace && sa_config.service_account_name == var.service_account_name ?
        aws_eks_pod_identity_association.primary[0].association_arn : aws_eks_pod_identity_association.target[sa_name].association_arn
      ) : null
    }
  } : {}
  description = "Complete service account configuration showing all service accounts, their namespaces, target roles, and association details"
}

output "service_account_summary" {
  value = local.enabled ? {
    total_count = length(local.service_accounts_map)
    traditional_count = length([
      for sa_name, sa_config in local.service_accounts_map : sa_name
      if !sa_config.has_target_role
    ])
    target_enabled_count = length([
      for sa_name, sa_config in local.service_accounts_map : sa_name
      if sa_config.has_target_role
    ])
    namespaces = distinct([
      for sa_config in values(local.service_accounts_map) : sa_config.namespace
    ])
  } : null
  description = "Summary statistics of service account configuration"
}
