# EKS Pod Identity Example

This example demonstrates how to use the `terraform-aws-eks-iam-role` module with **EKS Pod Identity** authentication mode.

## Features Demonstrated

- **AWS Load Balancer Controller** role with Pod Identity
- **External DNS** role with Pod Identity  
- No requirement for OIDC issuer URL (simplified setup)
- Clean service principal-based trust policy

## Key Differences from IRSA

### EKS Pod Identity (this example)
```hcl
module "aws_load_balancer_controller" {
  source = "../.."
  
  authentication_mode = "pod_identity"
  
  service_account_name      = "aws-load-balancer-controller"
  service_account_namespace = "kube-system"
  
  # No eks_cluster_oidc_issuer_url required!
  aws_iam_policy_document = [data.aws_iam_policy_document.aws_load_balancer_controller.json]
}
```

### IRSA (traditional approach)
```hcl
module "aws_load_balancer_controller" {
  source = "../.."
  
  authentication_mode = "irsa"  # or omit (defaults to irsa)
  
  service_account_name      = "aws-load-balancer-controller"
  service_account_namespace = "kube-system"
  
  # Required for IRSA
  eks_cluster_oidc_issuer_url = "https://oidc.eks.region.amazonaws.com/id/EXAMPLE"
  aws_iam_policy_document = [data.aws_iam_policy_document.aws_load_balancer_controller.json]
}
```

## Trust Policy Comparison

### Pod Identity Trust Policy
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "pods.eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

### IRSA Trust Policy  
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT:oidc-provider/oidc.eks.REGION.amazonaws.com/id/EXAMPLE"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.REGION.amazonaws.com/id/EXAMPLE:aud": "sts.amazonaws.com",
          "oidc.eks.REGION.amazonaws.com/id/EXAMPLE:sub": "system:serviceaccount:NAMESPACE:SERVICEACCOUNT"
        }
      }
    }
  ]
}
```

## Prerequisites

1. **EKS Cluster** with EKS Pod Identity support (Kubernetes 1.24+)
2. **Pod Identity Agent** installed on the cluster
3. **Service accounts** created in the appropriate namespaces

## Usage

```bash
terraform init
terraform plan -var eks_cluster_name="your-cluster-name"
terraform apply -var eks_cluster_name="your-cluster-name"
```

## What This Example Creates

This example creates:

1. **IAM Roles** with Pod Identity trust policy for:
   - AWS Load Balancer Controller
   - External DNS

2. **EKS Pod Identity Associations** that automatically link:
   - IAM roles to Kubernetes service accounts
   - No manual `aws eks create-pod-identity-association` commands needed!

## Creating EKS Pod Identity Associations

**The module automatically creates the Pod Identity associations!** Unlike the manual approach shown in AWS documentation, this Terraform module handles the association creation for you using the `aws_eks_pod_identity_association` resource.

After applying this Terraform configuration, the associations are ready to use. You just need to ensure your Kubernetes service accounts exist:

```bash
# Create the service accounts if they don't exist
kubectl create serviceaccount aws-load-balancer-controller -n kube-system
kubectl create namespace external-dns
kubectl create serviceaccount external-dns -n external-dns
```

**No annotations needed!** Unlike IRSA, Pod Identity doesn't require service account annotations.

## Benefits of EKS Pod Identity

- **Simpler Setup**: No OIDC provider configuration required
- **Better Scalability**: Reduced API calls compared to IRSA
- **Cross-Account Friendly**: Single service principal works across accounts
- **Independent Operations**: Clean separation between EKS and IAM configuration

## Migration from IRSA

To migrate existing roles from IRSA to Pod Identity:

1. Update the module configuration: `authentication_mode = "pod_identity"`
2. Remove `eks_cluster_oidc_issuer_url` (optional for Pod Identity)
3. Apply Terraform changes (will replace the IAM role)
4. Update EKS Pod Identity associations instead of service account annotations
5. Restart affected pods to pick up new authentication method