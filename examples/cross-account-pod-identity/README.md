# Cross-Account EKS Pod Identity Example

This example demonstrates how to use EKS Pod Identity with cross-account role assumption capabilities, showcasing the
N:1:N relationship where multiple ServiceAccounts share one primary role while accessing different target roles.

## Architecture Overview

This example creates three different Pod Identity configurations, each demonstrating different cross-account access
patterns:

1. **Data Analytics Pod** - Single ServiceAccount with one cross-account target role
2. **CI/CD Pipeline Pods** - Multiple ServiceAccounts with mixed target roles (same-account and cross-account)
3. **Monitoring Pods** - Multiple ServiceAccounts accessing different account environments

## N:1:N Relationship Demonstrated

The key architectural pattern shown here is:

- **N ServiceAccounts** → **1 Shared Primary Role** → **N Target Roles** (1:1 SA-to-Target mapping)

Each ServiceAccount gets:

- Access to the **shared primary role** permissions (defined in `aws_iam_policy_document`)
- Access to its **specific target role** (defined in `target_role_arns` map)

## Prerequisites

Before running this example, you need:

1. **EKS Cluster** with Pod Identity enabled in your current account
2. **Target Account Roles** configured to trust your Pod Identity roles
3. **AWS CLI** configured with appropriate permissions

## Target Account Setup

For each target AWS account, you need to create roles that trust your Pod Identity roles. Here's an example trust
policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::SOURCE-ACCOUNT-ID:role/SOURCE-ROLE-NAME"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

## Usage

1. **Configure your variables** (see `variables.tf` for all options):

   ```bash
   # Update variables in terraform.tfvars or via command line
   data_lake_account_id = "111111111111"
   staging_account_id = "333333333333"
   production_account_id = "444444444444"
   # ... other account IDs
   ```

2. **Deploy the infrastructure**:

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

3. **Verify Pod Identity associations**:
   ```bash
   # List all Pod Identity associations
   aws eks list-pod-identity-associations --cluster-name YOUR-CLUSTER
   ```

## Using Cross-Account Roles in Your Pods

Once deployed, your pods can assume cross-account roles using the AWS SDK. EKS Pod Identity handles the authentication
automatically.

### Python Example

```python
import boto3

def assume_cross_account_role(role_arn, session_name='pod-session'):
    """Assume a cross-account role using Pod Identity credentials."""
    sts_client = boto3.client('sts')

    response = sts_client.assume_role(
        RoleArn=role_arn,
        RoleSessionName=session_name
    )

    # Use temporary credentials
    credentials = response['Credentials']
    return boto3.Session(
        aws_access_key_id=credentials['AccessKeyId'],
        aws_secret_access_key=credentials['SecretAccessKey'],
        aws_session_token=credentials['SessionToken']
    )

# Example usage in your data analytics pod
cross_account_session = assume_cross_account_role(
    role_arn="arn:aws:iam::111111111111:role/DataLakeReadOnlyAccess"
)
s3_client = cross_account_session.client('s3')
```

### Node.js Example

```javascript
const AWS = require("aws-sdk");

async function assumeCrossAccountRole(roleArn, sessionName = "pod-session") {
  const sts = new AWS.STS();

  const response = await sts
    .assumeRole({
      RoleArn: roleArn,
      RoleSessionName: sessionName,
    })
    .promise();

  return new AWS.Config({
    accessKeyId: response.Credentials.AccessKeyId,
    secretAccessKey: response.Credentials.SecretAccessKey,
    sessionToken: response.Credentials.SessionToken,
  });
}

// Example usage
const crossAccountConfig = await assumeCrossAccountRole("arn:aws:iam::111111111111:role/DataLakeReadOnlyAccess");
const s3 = new AWS.S3(crossAccountConfig);
```

## Security Best Practices

1. **Least Privilege**: Grant minimal permissions in target account roles
2. **Monitor Cross-Account Access**: Use CloudTrail to monitor cross-account role assumptions
3. **Regular Review**: Periodically review target role permissions and usage
4. **Account Isolation**: Use separate roles for different environments (dev/staging/prod)
5. **Session Naming**: Use descriptive session names for better audit trails

## Example Output

After applying, you'll see outputs like:

```
data_analytics_role_arn = "arn:aws:iam::123456789012:role/example-data-analytics"
cicd_role_arn = "arn:aws:iam::123456789012:role/example-cicd"
monitoring_role_arn = "arn:aws:iam::123456789012:role/example-monitoring"

pod_identity_associations = {
  data_analytics = {
    all_association_arns = [
      "arn:aws:eks:us-west-2:123456789012:podidentityassociation/my-cluster/a-abc123",
      "arn:aws:eks:us-west-2:123456789012:podidentityassociation/my-cluster/a-def456"
    ]
    service_accounts = {
      "analytics:data-analytics" = {
        has_target_role = true
        target_role_arn = "arn:aws:iam::111111111111:role/DataLakeReadOnlyAccess"
      }
    }
  }
}
```

## Troubleshooting

### Common Issues

1. **"Access Denied" when assuming cross-account role**:
   - Verify the target account role trust policy includes your source role ARN
   - Ensure the target role has the necessary permissions for your use case
   - Check that the source role has `sts:AssumeRole` permissions

2. **Pod Identity association not found**:
   - Verify EKS cluster name is correct
   - Ensure Pod Identity is enabled on your EKS cluster (requires EKS 1.24+)
   - Check that the ServiceAccount name matches the association

3. **ServiceAccount not found in Kubernetes**:
   - ServiceAccounts are not automatically created by Pod Identity associations
   - Create them manually: `kubectl create serviceaccount SA-NAME -n NAMESPACE`

### Validation Commands

```bash
# Test cross-account role assumption (from within a pod)
aws sts assume-role \
  --role-arn "arn:aws:iam::TARGET-ACCOUNT:role/TARGET-ROLE" \
  --role-session-name "test-session"

# List Pod Identity associations
aws eks list-pod-identity-associations --cluster-name YOUR-CLUSTER

# Describe a specific association
aws eks describe-pod-identity-association \
  --cluster-name YOUR-CLUSTER \
  --association-id ASSOCIATION-ID

# Check ServiceAccount exists in Kubernetes
kubectl get serviceaccount -n NAMESPACE
```

### Debug Pod Credentials

```bash
# From within a pod, check current credentials
aws sts get-caller-identity

# Check environment variables
env | grep AWS_
```

## Clean Up

To clean up all resources:

```bash
terraform destroy
```

**Important**: This will remove all Pod Identity associations and IAM roles. Ensure no workloads are actively using
these roles before destroying.

## Advanced Configuration

### Mixed Same-Account and Cross-Account Access

The CI/CD example demonstrates how to configure both same-account and cross-account target roles:

```hcl
target_role_arns = {
  "cicd:staging-deployer" = "arn:aws:iam::333333333333:role/EKSDeploymentRole"  # Cross-account
  "cicd:prod-deployer"    = "arn:aws:iam::444444444444:role/EKSDeploymentRole"  # Cross-account
  "cicd:security-scanner" = "arn:aws:iam::123456789012:role/ElevatedSecurityRole" # Same-account
}
```

### Environment-Specific Monitoring

The monitoring example shows how different ServiceAccounts can access different environments:

```hcl
target_role_arns = {
  "monitoring:dev-collector"     = "arn:aws:iam::555555555555:role/MetricsReadOnlyAccess"
  "monitoring:staging-collector" = "arn:aws:iam::333333333333:role/MetricsReadOnlyAccess"
  "monitoring:prod-collector"    = "arn:aws:iam::444444444444:role/MetricsReadOnlyAccess"
}
```

This pattern allows you to deploy a single monitoring stack that can collect metrics from all your environments while
maintaining proper access controls.

