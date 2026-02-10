output "data_analytics_role_arn" {
  value       = module.data_analytics_cross_account.service_account_role_arn
  description = "IAM role ARN for data analytics pod with cross-account access"
}

output "data_analytics_cross_account_enabled" {
  value       = module.data_analytics_cross_account.cross_account_enabled
  description = "Whether cross-account access is enabled for data analytics role"
}

output "cicd_role_arn" {
  value       = module.cicd_cross_account.service_account_role_arn
  description = "IAM role ARN for CI/CD pod with cross-account deployment access"
}

output "cicd_target_roles_enabled" {
  value       = module.cicd_cross_account.target_roles_enabled
  description = "Whether CI/CD role has target role assumption enabled"
}

output "monitoring_target_roles" {
  value       = module.monitoring_cross_account.target_role_arns
  description = "List of target roles that monitoring pod can assume (includes same-account and cross-account)"
}

output "monitoring_cross_account_roles" {
  value       = module.monitoring_cross_account.cross_account_target_arns
  description = "List of cross-account target roles that monitoring pod can assume"
}

output "monitoring_role_arn" {
  value       = module.monitoring_cross_account.service_account_role_arn
  description = "IAM role ARN for monitoring pod with cross-account metrics access"
}

# Pod Identity Association Information - Enhanced
output "pod_identity_associations" {
  value = {
    data_analytics = {
      all_association_arns = module.data_analytics_cross_account.pod_identity_association_arns
      all_associations     = module.data_analytics_cross_account.pod_identity_associations
      service_accounts     = module.data_analytics_cross_account.service_accounts
    }
    cicd = {
      all_association_arns = module.cicd_cross_account.pod_identity_association_arns
      all_associations     = module.cicd_cross_account.pod_identity_associations
      service_accounts     = module.cicd_cross_account.service_accounts
    }
    monitoring = {
      all_association_arns = module.monitoring_cross_account.pod_identity_association_arns
      all_associations     = module.monitoring_cross_account.pod_identity_associations
      service_accounts     = module.monitoring_cross_account.service_accounts
    }
  }
  description = "Comprehensive Pod Identity association details showing N:1:N relationship"
}

# Target Role Breakdown - demonstrates mixed same-account and cross-account
output "cicd_target_role_breakdown" {
  value = {
    all_target_roles      = module.cicd_cross_account.target_role_arns
    same_account_targets  = module.cicd_cross_account.same_account_target_arns
    cross_account_targets = module.cicd_cross_account.cross_account_target_arns
    target_roles_enabled  = module.cicd_cross_account.target_roles_enabled
    cross_account_enabled = module.cicd_cross_account.cross_account_enabled
  }
  description = "Breakdown showing mixed same-account and cross-account target roles for CI/CD"
}