provider "aws" {
  region = var.region
}

locals {
  enabled = module.this.enabled
}

data "aws_caller_identity" "current" {
  count = local.enabled ? 1 : 0
}

# Example 1: Data Analytics Pod
# This pod can assume roles in multiple accounts for data processing
module "data_analytics_cross_account" {
  source = "../.."

  # Use Pod Identity authentication mode
  authentication_mode = "pod_identity"
  eks_cluster_name    = var.eks_cluster_name

  # Define the primary ServiceAccount that will be created with shared IAM role
  service_account_name      = "data-analytics"
  service_account_namespace = "analytics"

  aws_account_number      = one(data.aws_caller_identity.current[*].account_id)
  aws_iam_policy_document = [one(data.aws_iam_policy_document.data_analytics[*].json)]

  # Target role configuration: Each ServiceAccount maps to one target role
  # Format: "namespace:service-account" = "target-role-arn"
  target_role_arns = {
    "analytics:data-analytics" = "arn:aws:iam::${var.data_lake_account_id}:role/DataLakeReadOnlyAccess"
  }

  context = module.this.context
}

# Example 2: Multi-ServiceAccount CI/CD Pipeline with Different Target Roles
# This shows the new N:1:N pattern - multiple SAs, one shared role, different target roles
module "cicd_cross_account" {
  source = "../.."

  attributes = ["cicd"]

  # Use Pod Identity authentication mode
  authentication_mode = "pod_identity"
  eks_cluster_name    = var.eks_cluster_name

  # Traditional ServiceAccounts (no target roles - only use shared primary role)
  service_account_namespace_name_list = [
    "cicd:build-agent", # Build agent only needs primary role permissions
    "cicd:test-runner"  # Test runner only needs primary role permissions
  ]

  aws_account_number      = one(data.aws_caller_identity.current[*].account_id)
  aws_iam_policy_document = [one(data.aws_iam_policy_document.cicd_deployment[*].json)]

  # Target-enabled ServiceAccounts: Each SA gets primary + specific target role
  target_role_arns = {
    # Staging deployment agent - can assume staging deployment role
    "cicd:staging-deployer" = "arn:aws:iam::${var.staging_account_id}:role/EKSDeploymentRole"
    # Production deployment agent - can assume production deployment role  
    "cicd:prod-deployer" = "arn:aws:iam::${var.production_account_id}:role/EKSDeploymentRole"
    # Security scanner - can assume elevated same-account role
    "cicd:security-scanner" = "arn:aws:iam::${one(data.aws_caller_identity.current[*].account_id)}:role/ElevatedSecurityRole"
  }

  context = module.this.context
}

# Example 3: Monitoring Pod with Multiple Cross-Account Access Patterns
module "monitoring_cross_account" {
  source = "../.."

  attributes = ["monitoring"]

  # Use Pod Identity authentication mode
  authentication_mode = "pod_identity"
  eks_cluster_name    = var.eks_cluster_name

  aws_account_number      = one(data.aws_caller_identity.current[*].account_id)
  aws_iam_policy_document = [one(data.aws_iam_policy_document.monitoring[*].json)]

  # Multiple monitoring ServiceAccounts, each accessing different account environments
  target_role_arns = {
    "monitoring:dev-collector"     = "arn:aws:iam::${var.dev_account_id}:role/MetricsReadOnlyAccess"
    "monitoring:staging-collector" = "arn:aws:iam::${var.staging_account_id}:role/MetricsReadOnlyAccess"
    "monitoring:prod-collector"    = "arn:aws:iam::${var.production_account_id}:role/MetricsReadOnlyAccess"
  }

  context = module.this.context
}

# IAM policy for data analytics workloads
data "aws_iam_policy_document" "data_analytics" {
  count = local.enabled ? 1 : 0

  statement {
    sid = "AllowS3ReadAccess"

    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:ListBucket"
    ]

    effect = "Allow"
    # Local account S3 access
    resources = [
      "arn:aws:s3:::${var.local_data_bucket}/*",
      "arn:aws:s3:::${var.local_data_bucket}"
    ]
  }

  statement {
    sid = "AllowCloudWatchLogs"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
      "logs:DescribeLogGroups"
    ]

    effect    = "Allow"
    resources = ["arn:aws:logs:${var.region}:${one(data.aws_caller_identity.current[*].account_id)}:*"]
  }
}

# IAM policy for CI/CD deployment
data "aws_iam_policy_document" "cicd_deployment" {
  count = local.enabled ? 1 : 0

  statement {
    sid = "AllowECRAccess"

    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:GetAuthorizationToken"
    ]

    effect    = "Allow"
    resources = ["*"]
  }

  statement {
    sid = "AllowParameterStoreAccess"

    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath"
    ]

    effect = "Allow"
    resources = [
      "arn:aws:ssm:${var.region}:${one(data.aws_caller_identity.current[*].account_id)}:parameter/cicd/*"
    ]
  }
}

# IAM policy for monitoring
data "aws_iam_policy_document" "monitoring" {
  count = local.enabled ? 1 : 0

  statement {
    sid = "AllowCloudWatchMetrics"

    actions = [
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:ListMetrics",
      "cloudwatch:GetMetricData"
    ]

    effect    = "Allow"
    resources = ["*"]
  }

  statement {
    sid = "AllowEC2ReadOnly"

    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeRegions",
      "ec2:DescribeAvailabilityZones"
    ]

    effect    = "Allow"
    resources = ["*"]
  }
}