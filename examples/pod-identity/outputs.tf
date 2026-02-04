output "aws_load_balancer_controller_role_arn" {
  value       = module.aws_load_balancer_controller.service_account_role_arn
  description = "ARN of IAM role for AWS Load Balancer Controller"
}

output "aws_load_balancer_controller_role_name" {
  value       = module.aws_load_balancer_controller.service_account_role_name
  description = "Name of IAM role for AWS Load Balancer Controller"
}

output "aws_load_balancer_controller_association_arn" {
  value       = module.aws_load_balancer_controller.pod_identity_association_arn
  description = "ARN of Pod Identity association for AWS Load Balancer Controller"
}

output "external_dns_role_arn" {
  value       = module.external_dns.service_account_role_arn
  description = "ARN of IAM role for External DNS"
}

output "external_dns_role_name" {
  value       = module.external_dns.service_account_role_name
  description = "Name of IAM role for External DNS"
}

output "external_dns_association_arn" {
  value       = module.external_dns.pod_identity_association_arn
  description = "ARN of Pod Identity association for External DNS"
}

output "authentication_modes" {
  value = {
    aws_load_balancer_controller = module.aws_load_balancer_controller.authentication_mode
    external_dns                 = module.external_dns.authentication_mode
  }
  description = "Authentication modes used for each role"
}