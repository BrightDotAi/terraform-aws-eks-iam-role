output "data_analytics_role_arn" {
  value       = module.data_analytics_cross_account.service_account_role_arn
  description = "IAM role ARN for data analytics pod with cross-account access"
}

output "data_analytics_external_id" {
  value       = module.data_analytics_cross_account.cross_account_external_id
  description = "Auto-generated external ID for data analytics cross-account access"
  sensitive   = true
}

output "data_analytics_cross_account_enabled" {
  value       = module.data_analytics_cross_account.cross_account_enabled
  description = "Whether cross-account access is enabled for data analytics role"
}

output "cicd_role_arn" {
  value       = module.cicd_cross_account.service_account_role_arn
  description = "IAM role ARN for CI/CD pod with cross-account deployment access"
}

output "cicd_external_id" {
  value       = module.cicd_cross_account.cross_account_external_id
  description = "Custom external ID for CI/CD cross-account access"
  sensitive   = true
}

output "cicd_cross_account_policy" {
  value       = module.cicd_cross_account.cross_account_policy_name
  description = "Name of CI/CD cross-account assume role policy"
}

output "monitoring_role_arn" {
  value       = module.monitoring_cross_account.service_account_role_arn
  description = "IAM role ARN for monitoring pod with cross-account metrics access"
}

output "monitoring_cross_account_roles" {
  value       = module.monitoring_cross_account.cross_account_role_arns
  description = "List of cross-account roles that monitoring pod can assume"
}

# Pod Identity Association Information
output "pod_identity_associations" {
  value = {
    data_analytics = {
      association_arn = module.data_analytics_cross_account.pod_identity_association_arn
      association_id  = module.data_analytics_cross_account.pod_identity_association_id
    }
    cicd = {
      association_arn = module.cicd_cross_account.pod_identity_association_arn
      association_id  = module.cicd_cross_account.pod_identity_association_id
    }
    monitoring = {
      association_arn = module.monitoring_cross_account.pod_identity_association_arn
      association_id  = module.monitoring_cross_account.pod_identity_association_id
    }
  }
  description = "Pod Identity association details for all cross-account roles"
}

# Summary of external ID configurations
output "external_id_summary" {
  value = {
    data_analytics = "auto-generated"
    cicd           = "custom-provided"
    monitoring     = "none (null)"
  }
  description = "Summary of external ID configurations for each role"
}