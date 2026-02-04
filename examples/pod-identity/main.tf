provider "aws" {
  region = var.region
}

locals {
  enabled = module.this.enabled
}

data "aws_caller_identity" "current" {
  count = local.enabled ? 1 : 0
}

# Example: AWS Load Balancer Controller using EKS Pod Identity
module "aws_load_balancer_controller" {
  source = "../.."

  # Use Pod Identity authentication mode
  authentication_mode = "pod_identity"
  eks_cluster_name    = var.eks_cluster_name

  service_account_name      = "aws-load-balancer-controller"
  service_account_namespace = "kube-system"

  aws_account_number      = one(data.aws_caller_identity.current[*].account_id)
  aws_iam_policy_document = [one(data.aws_iam_policy_document.aws_load_balancer_controller[*].json)]

  context = module.this.context
}

# Example: External DNS using EKS Pod Identity
module "external_dns" {
  source = "../.."

  attributes = ["external-dns"]

  # Use Pod Identity authentication mode
  authentication_mode = "pod_identity"
  eks_cluster_name    = var.eks_cluster_name

  service_account_name      = "external-dns"
  service_account_namespace = "external-dns"

  aws_account_number      = one(data.aws_caller_identity.current[*].account_id)
  aws_iam_policy_document = [one(data.aws_iam_policy_document.external_dns[*].json)]

  context = module.this.context
}

# IAM policy for AWS Load Balancer Controller
data "aws_iam_policy_document" "aws_load_balancer_controller" {
  count = local.enabled ? 1 : 0

  statement {
    sid = "AllowLoadBalancerControllerOperations"

    actions = [
      "iam:CreateServiceLinkedRole",
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeAddresses",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeVpcs",
      "ec2:DescribeVpcPeeringConnections",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeInstances",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeTags",
      "ec2:GetCoipPoolUsage",
      "ec2:DescribeCoipPools",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeLoadBalancerAttributes",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeListenerCertificates",
      "elasticloadbalancing:DescribeSSLPolicies",
      "elasticloadbalancing:DescribeRules",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTargetGroupAttributes",
      "elasticloadbalancing:DescribeTargetHealth",
      "elasticloadbalancing:DescribeTags",
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:CreateTargetGroup",
      "elasticloadbalancing:CreateListener",
      "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:DeleteTargetGroup",
      "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:DeregisterTargets",
      "elasticloadbalancing:SetWebAcl",
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:ModifyTargetGroup",
      "elasticloadbalancing:ModifyTargetGroupAttributes",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:AddListenerCertificates",
      "elasticloadbalancing:RemoveListenerCertificates",
      "elasticloadbalancing:ModifyRule"
    ]

    effect    = "Allow"
    resources = ["*"]
  }
}

# IAM policy for External DNS
data "aws_iam_policy_document" "external_dns" {
  count = local.enabled ? 1 : 0

  statement {
    sid = "AllowRoute53Operations"

    actions = [
      "route53:ChangeResourceRecordSets",
      "route53:ListHostedZones",
      "route53:ListResourceRecordSets",
      "route53:ListTagsForResource"
    ]

    effect    = "Allow"
    resources = ["*"]
  }
}