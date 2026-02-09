locals {
  enabled = module.this.enabled

  eks_cluster_oidc_issuer = local.enabled && var.eks_cluster_oidc_issuer_url != null ? replace(var.eks_cluster_oidc_issuer_url, "https://", "") : ""

  aws_account_number = local.enabled ? coalesce(var.aws_account_number, data.aws_caller_identity.current[0].account_id) : ""

  # EXISTING: Traditional service account resolution (for SAs without target roles)
  single_service_account = var.service_account_name == null && var.service_account_namespace == null && length(var.service_account_namespace_name_list) > 0 ? [] : [
    format("%s:%s", coalesce(var.service_account_namespace, "*"), coalesce(var.service_account_name, "*"))
  ]
  traditional_service_account_list = concat(local.single_service_account, var.service_account_namespace_name_list)

  # NEW: Service accounts from target_role_arns
  target_service_account_list = keys(var.target_role_arns)

  # NEW: Duplicate detection (extract SA names, accounting for wildcards)
  traditional_sa_names = [
    for sa_entry in local.traditional_service_account_list :
    split(":", sa_entry)[1]
    if !contains(["*", "all"], split(":", sa_entry)[1])
  ]

  target_sa_names = [
    for sa_entry in local.target_service_account_list :
    split(":", sa_entry)[1]
  ]

  duplicate_sa_names = setintersection(toset(local.traditional_sa_names), toset(local.target_sa_names))

  # NEW: Combined service account list
  all_service_account_list = concat(
    local.traditional_service_account_list,
    local.target_service_account_list
  )

  # NEW: Extract namespace and SA names from target_role_arns keys for validation
  target_role_sa_entries = [
    for sa_key in keys(var.target_role_arns) : {
      namespace = split(":", sa_key)[0]
      sa_name   = split(":", sa_key)[1]
      full_key  = sa_key
    }
  ]

  # NEW: Check for invalid K8s names when using Pod Identity
  invalid_pod_identity_entries = var.authentication_mode == "pod_identity" ? [
    for entry in local.target_role_sa_entries :
    entry.full_key
    if contains(["*", "all"], entry.namespace) ||
    contains(["*", "all"], entry.sa_name) ||
    !can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", entry.namespace)) ||
    !can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", entry.sa_name))
  ] : []

  # NEW: Structured service account map
  service_accounts_map = {
    for sa_entry in local.all_service_account_list :
    split(":", sa_entry)[1] => {
      namespace            = split(":", sa_entry)[0]
      service_account_name = split(":", sa_entry)[1]
      full_id              = sa_entry
      has_target_role      = contains(local.target_service_account_list, sa_entry)
      target_role_arn      = contains(local.target_service_account_list, sa_entry) ? var.target_role_arns[sa_entry] : null
      is_wildcard          = contains(["*", "all"], split(":", sa_entry)[1]) || contains(["*", "all"], split(":", sa_entry)[0])
    }
    # For Pod Identity: exclude wildcards; For IRSA: include all
    if var.authentication_mode == "irsa" || (!contains(["*", "all"], split(":", sa_entry)[1]) && !contains(["*", "all"], split(":", sa_entry)[0]))
  }

  # NEW: Service accounts with target roles (for target associations)
  service_accounts_with_targets = {
    for sa_name, sa_config in local.service_accounts_map :
    sa_name => sa_config
    if sa_config.has_target_role
  }

  # EXISTING: Role naming logic (updated to use merged list)
  service_account_namespace_name_list = local.all_service_account_list
  role_name_service_account_name      = replace(split(":", local.service_account_namespace_name_list[0])[1], "*", "all")
  role_name_namespace                 = replace(split(":", local.service_account_namespace_name_list[0])[0], "*", "all")
  service_account_long_id             = format("%v@%v", local.role_name_service_account_name, local.role_name_namespace)
  service_account_id                  = trimsuffix(local.service_account_long_id, format("@%v", local.role_name_service_account_name))

  # NEW: Target role analysis (updated for map values)
  all_target_arns = values(var.target_role_arns)
  cross_account_target_arns = [
    for target_arn in local.all_target_arns :
    target_arn if split(":", target_arn)[4] != local.aws_account_number
  ]
  same_account_target_arns = [
    for target_arn in local.all_target_arns :
    target_arn if split(":", target_arn)[4] == local.aws_account_number
  ]

  # Updated: Target roles enabled flag
  target_roles_enabled = local.enabled && length(var.target_role_arns) > 0

  # EXISTING: Policy document handling (unchanged)
  aws_iam_policy_document = try(var.aws_iam_policy_document[0], tostring(var.aws_iam_policy_document), "{}")
  iam_policy_enabled      = local.enabled && length(var.aws_iam_policy_document) > 0
}

data "aws_caller_identity" "current" {
  count = local.enabled ? 1 : 0
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

# Validation for duplicate ServiceAccount names
resource "null_resource" "validate_no_duplicate_sas" {
  count = local.enabled && length(local.duplicate_sa_names) > 0 ? 1 : 0

  lifecycle {
    precondition {
      condition     = length(local.duplicate_sa_names) == 0
      error_message = "ServiceAccount names cannot be defined in both traditional service_account_* variables AND target_role_arns. Duplicate ServiceAccount names found: ${join(", ", local.duplicate_sa_names)}"
    }
  }
}

# Validation for Pod Identity naming requirements
resource "null_resource" "validate_pod_identity_names" {
  count = local.enabled && var.authentication_mode == "pod_identity" && length(local.invalid_pod_identity_entries) > 0 ? 1 : 0

  lifecycle {
    precondition {
      condition     = length(local.invalid_pod_identity_entries) == 0
      error_message = "Pod Identity mode requires valid Kubernetes names (no wildcards, patterns, or invalid characters) in target_role_arns keys. Invalid entries: ${join(", ", local.invalid_pod_identity_entries)}"
    }
  }
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
    sid     = "AllowEksAuthToAssumeRoleForPodIdentity"
    actions = ["sts:AssumeRole", "sts:TagSession"]
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
resource "aws_eks_pod_identity_association" "primary" {
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
  }
}

# Target role associations - ONLY service accounts defined in target_role_arns
resource "aws_eks_pod_identity_association" "target" {
  for_each = local.enabled && var.authentication_mode == "pod_identity" ? local.service_accounts_with_targets : {}

  cluster_name    = var.eks_cluster_name
  namespace       = each.value.namespace
  service_account = each.key
  role_arn        = aws_iam_role.service_account[0].arn
  target_role_arn = each.value.target_role_arn

  tags = module.service_account_label.tags

  lifecycle {
    precondition {
      condition     = var.eks_cluster_name != null
      error_message = "eks_cluster_name must be provided when using Pod Identity authentication mode."
    }
  }
}

# IAM policy document for target role assumption
data "aws_iam_policy_document" "target_role_assume" {
  count = local.target_roles_enabled ? 1 : 0

  statement {
    effect    = "Allow"
    actions   = ["sts:AssumeRole", "sts:TagSession"]
    resources = local.all_target_arns
  }
}

resource "aws_iam_policy" "target_role_assume" {
  count = local.target_roles_enabled ? 1 : 0

  name        = "${module.service_account_label.id}-target-assume"
  description = "Allows primary role for EKS pod identity to assume target roles."
  path        = "/"
  policy      = data.aws_iam_policy_document.target_role_assume[0].json
}

# Attach target role assume policy as customer-managed policy
resource "aws_iam_role_policy_attachment" "target_role_assume" {
  count = local.target_roles_enabled ? 1 : 0

  role       = aws_iam_role.service_account[0].id
  policy_arn = aws_iam_policy.target_role_assume[0].arn
}
