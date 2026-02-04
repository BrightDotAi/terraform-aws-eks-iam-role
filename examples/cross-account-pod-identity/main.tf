provider "aws" {
  region = var.region
}

locals {
  enabled = module.this.enabled
}

data "aws_caller_identity" "current" {
  count = local.enabled ? 1 : 0
}

# Example 1: Data Analytics Pod with Auto-Generated External ID
# This pod can assume roles in multiple accounts for data processing
module "data_analytics_cross_account" {
  source = "../.."

  # Use Pod Identity authentication mode
  authentication_mode = "pod_identity"
  eks_cluster_name    = var.eks_cluster_name

  service_account_name      = "data-analytics"
  service_account_namespace = "analytics"

  aws_account_number      = one(data.aws_caller_identity.current[*].account_id)
  aws_iam_policy_document = [one(data.aws_iam_policy_document.data_analytics[*].json)]

  # Cross-account configuration with auto-generated external ID
  cross_account_role_arns = [
    "arn:aws:iam::${var.data_lake_account_id}:role/DataLakeReadOnlyAccess",
    "arn:aws:iam::${var.ml_models_account_id}:role/MLModelsAccess"
  ]
  cross_account_external_id = "auto"  # Auto-generate for security

  context = module.this.context
}

# Example 2: CI/CD Pipeline Pod with Custom External ID  
# This pod deploys applications to multiple environments in different accounts
module "cicd_cross_account" {
  source = "../.."

  attributes = ["cicd"]

  # Use Pod Identity authentication mode
  authentication_mode = "pod_identity"
  eks_cluster_name    = var.eks_cluster_name

  service_account_name      = "deployment-agent"
  service_account_namespace = "cicd"

  aws_account_number      = one(data.aws_caller_identity.current[*].account_id)
  aws_iam_policy_document = [one(data.aws_iam_policy_document.cicd_deployment[*].json)]

  # Cross-account configuration with custom external ID
  cross_account_role_arns = [
    "arn:aws:iam::${var.staging_account_id}:role/EKSDeploymentRole",
    "arn:aws:iam::${var.production_account_id}:role/EKSDeploymentRole"
  ]
  cross_account_external_id = var.cicd_external_id  # Custom external ID for production security

  context = module.this.context
}

# Example 3: Monitoring Pod with No External ID
# This pod collects metrics from trusted internal accounts
module "monitoring_cross_account" {
  source = "../.."

  attributes = ["monitoring"]

  # Use Pod Identity authentication mode
  authentication_mode = "pod_identity"
  eks_cluster_name    = var.eks_cluster_name

  service_account_name      = "prometheus-collector"
  service_account_namespace = "monitoring"

  aws_account_number      = one(data.aws_caller_identity.current[*].account_id)
  aws_iam_policy_document = [one(data.aws_iam_policy_document.monitoring[*].json)]

  # Cross-account configuration without external ID (trusted environment)
  cross_account_role_arns = [
    "arn:aws:iam::${var.dev_account_id}:role/MetricsReadOnlyAccess",
    "arn:aws:iam::${var.staging_account_id}:role/MetricsReadOnlyAccess"
  ]
  cross_account_external_id = null  # No external ID for trusted internal accounts

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