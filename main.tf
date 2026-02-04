locals {
  enabled = module.this.enabled

  eks_cluster_oidc_issuer = local.enabled && var.eks_cluster_oidc_issuer_url != null ? replace(var.eks_cluster_oidc_issuer_url, "https://", "") : ""

  aws_account_number = local.enabled ? coalesce(var.aws_account_number, data.aws_caller_identity.current[0].account_id) : ""

  # Cross-account specific locals
  cross_account_enabled     = local.enabled && length(var.cross_account_role_arns) > 0
  cross_account_external_id = var.cross_account_external_id == "auto" ? random_id.cross_account_external_id[0].hex : var.cross_account_external_id

  # Extract account IDs from cross-account role ARNs for validation
  cross_account_account_ids = [
    for arn in var.cross_account_role_arns :
    split(":", arn)[4] if can(regex("^arn:aws:iam::[0-9]{12}:role/.+", arn))
  ]

  # If both var.service_account_namespace and var.service_account_name are provided,
  # then the role ARN will have one of the following formats:
  # 1. if var.service_account_namespace != var.service_account_name: arn:aws:iam::<account_number>:role/<namespace>-<environment>-<stage>-<optional_name>-<service_account_name>@<service_account_namespace>
  # 2. if var.service_account_namespace == var.service_account_name: arn:aws:iam::<account_number>:role/<namespace>-<environment>-<stage>-<optional_name>-<service_account_name>

  # 3. If var.service_account_namespace == "" and var.service_account_name is provided,
  # then the role ARN will have format arn:aws:iam::<account_number>:role/<namespace>-<environment>-<stage>-<optional_name>-<service_account_name>@all,
  # and the policy will use a wildcard for the namespace in the test condition to allow ServiceAccounts in any Kubernetes namespace to assume the role (useful for unlimited preview environments)

  # 4. If var.service_account_name == "" and var.service_account_namespace is provided,
  # then the role ARN will have format arn:aws:iam::<account_number>:role/<namespace>-<environment>-<stage>-<optional_name>-all@<service_account_namespace>,
  # and the policy will use a wildcard for the service account name in the test condition to allow any ServiceAccount in the given namespace to assume the role.
  # For more details, see https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts-technical-overview.html#iam-role-configuration

  # 5. If both var.service_account_name == "" and var.service_account_namespace == "",
  # then the role ARN will have format arn:aws:iam::<account_number>:role/<namespace>-<environment>-<stage>-<optional_name>-all@all,
  # and the policy will use wildcards for both the namespace and the service account name in the test condition to allow all ServiceAccounts
  # in all Kubernetes namespaces to assume the IAM role (not recommended).


  single_service_account = var.service_account_name == null && var.service_account_namespace == null && length(var.service_account_namespace_name_list) > 0 ? [] : [
    format("%s:%s", coalesce(var.service_account_namespace, "*"), coalesce(var.service_account_name, "*"))
  ]
  service_account_namespace_name_list = concat(local.single_service_account, var.service_account_namespace_name_list)

  role_name_service_account_name = replace(split(":", local.service_account_namespace_name_list[0])[1], "*", "all")
  role_name_namespace            = replace(split(":", local.service_account_namespace_name_list[0])[0], "*", "all")
  service_account_long_id        = format("%v@%v", local.role_name_service_account_name, local.role_name_namespace)
  service_account_id             = trimsuffix(local.service_account_long_id, format("@%v", local.role_name_service_account_name))

  # Try to return the first element, if that doesn't work, try the tostring approach
  aws_iam_policy_document = try(var.aws_iam_policy_document[0], tostring(var.aws_iam_policy_document), "{}")
  iam_policy_enabled      = local.enabled && length(var.aws_iam_policy_document) > 0
}

data "aws_caller_identity" "current" {
  count = local.enabled ? 1 : 0
}

# Generate random external ID when "auto" is specified
resource "random_id" "cross_account_external_id" {
  count       = local.enabled && var.cross_account_external_id == "auto" ? 1 : 0
  byte_length = 16 # 32-character hex string for strong security
}

module "service_account_label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  # To remain consistent with our other modules, the service account name goes after
  # user-supplied attributes, not before.
  attributes = [local.service_account_id]

  # The standard module does not allow @ but we want it
  regex_replace_chars = "/[^-a-zA-Z0-9@_]/"
  id_length_limit     = 64

  context = module.this.context
}

resource "aws_iam_role" "service_account" {
  count                = local.enabled ? 1 : 0
  name                 = module.service_account_label.id
  description          = format("Role assumed by EKS ServiceAccount %s using %s", local.service_account_id, var.authentication_mode == "irsa" ? "IRSA" : "Pod Identity")
  assume_role_policy   = var.authentication_mode == "irsa" ? data.aws_iam_policy_document.service_account_assume_role[0].json : data.aws_iam_policy_document.service_account_assume_role_pod_identity[0].json
  tags                 = module.service_account_label.tags
  permissions_boundary = var.permissions_boundary
}

data "aws_iam_policy_document" "service_account_assume_role" {
  count = local.enabled && var.authentication_mode == "irsa" ? 1 : 0

  statement {
    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [format("arn:%s:iam::%s:oidc-provider/%s", var.aws_partition, local.aws_account_number, local.eks_cluster_oidc_issuer)]
    }

    condition {
      test     = "StringLike"
      values   = formatlist("system:serviceaccount:%s", local.service_account_namespace_name_list)
      variable = format("%s:sub", local.eks_cluster_oidc_issuer)

    }
    condition {
      test     = "StringEquals"
      values   = ["sts.amazonaws.com"]
      variable = format("%s:aud", local.eks_cluster_oidc_issuer)
    }
  }

  lifecycle {
    precondition {
      condition     = var.authentication_mode == "pod_identity" || (var.authentication_mode == "irsa" && var.eks_cluster_oidc_issuer_url != null && length(local.eks_cluster_oidc_issuer) > 0)
      error_message = "The eks_cluster_oidc_issuer_url value must be provided when using IRSA authentication mode."
    }
  }
}

data "aws_iam_policy_document" "service_account_assume_role_pod_identity" {
  count = local.enabled && var.authentication_mode == "pod_identity" ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "service_account" {
  count       = local.iam_policy_enabled ? 1 : 0
  name        = module.service_account_label.id
  description = format("Grant permissions to EKS ServiceAccount %s", local.service_account_id)
  policy      = local.aws_iam_policy_document
  tags        = module.service_account_label.tags
}

resource "aws_iam_role_policy_attachment" "service_account" {
  count      = local.iam_policy_enabled ? 1 : 0
  role       = aws_iam_role.service_account[0].name
  policy_arn = aws_iam_policy.service_account[0].arn
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each   = local.enabled ? var.managed_policy_arns : []
  role       = aws_iam_role.service_account[0].name
  policy_arn = each.key
}

# EKS Pod Identity Association - links the IAM role to the Kubernetes service account
resource "aws_eks_pod_identity_association" "this" {
  count = local.enabled && var.authentication_mode == "pod_identity" ? 1 : 0

  cluster_name    = var.eks_cluster_name
  namespace       = var.service_account_namespace
  service_account = var.service_account_name
  role_arn        = aws_iam_role.service_account[0].arn

  tags = module.service_account_label.tags

  lifecycle {
    precondition {
      condition     = var.eks_cluster_name != null
      error_message = "eks_cluster_name must be provided when using Pod Identity authentication mode."
    }

    precondition {
      condition     = var.service_account_name != null
      error_message = "service_account_name must be provided when using Pod Identity authentication mode."
    }

    precondition {
      condition     = var.service_account_namespace != null
      error_message = "service_account_namespace must be provided when using Pod Identity authentication mode."
    }
  }
}

# IAM policy document for cross-account role assumption
data "aws_iam_policy_document" "cross_account_assume_role" {
  count = local.cross_account_enabled ? 1 : 0

  statement {
    sid     = "AssumeRolesInOtherAccounts"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    resources = var.cross_account_role_arns

    # Conditionally add external ID requirement if specified
    dynamic "condition" {
      for_each = local.cross_account_external_id != null ? [1] : []
      content {
        test     = "StringEquals"
        variable = "sts:ExternalId"
        values   = [local.cross_account_external_id]
      }
    }
  }
}

# Attach cross-account assume role policy as inline policy
resource "aws_iam_role_policy" "cross_account_assume_role" {
  count = local.cross_account_enabled ? 1 : 0

  name   = "${module.service_account_label.id}-cross-account-assume"
  role   = aws_iam_role.service_account[0].id
  policy = data.aws_iam_policy_document.cross_account_assume_role[0].json
}
