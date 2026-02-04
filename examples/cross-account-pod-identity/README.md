# Cross-Account EKS Pod Identity Example

This example demonstrates how to use EKS Pod Identity with cross-account role assumption capabilities. It shows three different security patterns for external ID usage.

## Architecture Overview

This example creates three different Pod Identity roles, each demonstrating a different cross-account access pattern:

1. **Data Analytics Pod** - Auto-generated external ID for enhanced security
2. **CI/CD Pipeline Pod** - Custom external ID for production-grade security  
3. **Monitoring Pod** - No external ID for trusted internal environments

## Security Patterns Demonstrated

### 1. Auto-Generated External ID (Recommended for Most Use Cases)
```hcl
cross_account_external_id = "auto"
```
- Terraform automatically generates a secure random external ID
- Balances security with convenience
- External ID is available as a sensitive output

### 2. Custom External ID (Recommended for Production)
```hcl
cross_account_external_id = "cicd-secure-external-id-2024"
```
- You provide a specific external ID string
- Maximum control over the security token
- Recommended for production environments

### 3. No External ID (Trusted Environments Only)
```hcl
cross_account_external_id = null
```
- No external ID condition in the assume role policy
- Simplest configuration but less secure
- Only suitable for highly trusted environments

## Prerequisites

Before running this example, you need:

1. **EKS Cluster** with Pod Identity enabled in your current account
2. **Target Account Roles** configured to trust your Pod Identity roles
3. **AWS CLI** configured with appropriate permissions

## Target Account Setup

For each target AWS account, you need to create roles that trust your Pod Identity roles. Here's an example trust policy:

### For Roles with External ID (Data Analytics & CI/CD)
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::YOUR-SOURCE-ACCOUNT:role/ROLE-NAME"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": "YOUR-EXTERNAL-ID"
        }
      }
    }
  ]
}
```

### For Roles without External ID (Monitoring)
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::YOUR-SOURCE-ACCOUNT:role/ROLE-NAME"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

## Running the Example

1. **Update variables** in `variables.tf` with your actual account IDs:
   ```hcl
   data_lake_account_id    = "111111111111"  # Your data lake account
   ml_models_account_id    = "222222222222"  # Your ML account
   staging_account_id      = "333333333333"  # Your staging account
   production_account_id   = "444444444444"  # Your production account
   dev_account_id          = "555555555555"  # Your dev account
   ```

2. **Initialize and apply**:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

3. **Get the external IDs** (for configuring target account roles):
   ```bash
   # Get auto-generated external ID for data analytics
   terraform output data_analytics_external_id
   
   # Get custom external ID for CI/CD
   terraform output cicd_external_id
   ```

## Using Cross-Account Roles in Your Pods

Once deployed, your pods can assume cross-account roles using the AWS SDK:

### Python Example
```python
import boto3

def assume_cross_account_role(role_arn, external_id=None):
    sts_client = boto3.client('sts')
    
    assume_role_args = {
        'RoleArn': role_arn,
        'RoleSessionName': 'pod-cross-account-session'
    }
    
    if external_id:
        assume_role_args['ExternalId'] = external_id
    
    response = sts_client.assume_role(**assume_role_args)
    
    # Use temporary credentials
    credentials = response['Credentials']
    return boto3.client(
        's3',  # or any other service
        aws_access_key_id=credentials['AccessKeyId'],
        aws_secret_access_key=credentials['SecretAccessKey'],
        aws_session_token=credentials['SessionToken']
    )

# Example usage in your data analytics pod
cross_account_s3 = assume_cross_account_role(
    role_arn="arn:aws:iam::111111111111:role/DataLakeReadOnlyAccess",
    external_id="auto-generated-external-id-from-terraform"
)
```

## Security Best Practices

1. **Use External IDs in Production**: Always use external IDs for production cross-account access
2. **Rotate External IDs Regularly**: Consider rotating custom external IDs periodically
3. **Least Privilege**: Grant minimal permissions in target account roles
4. **Monitor Cross-Account Access**: Use CloudTrail to monitor cross-account role assumptions
5. **Validate Account IDs**: The module validates that target role ARNs are from different accounts

## Example Output

After applying, you'll see outputs like:

```
data_analytics_role_arn = "arn:aws:iam::123456789012:role/example-data-analytics@analytics"
data_analytics_external_id = <sensitive>
cicd_role_arn = "arn:aws:iam::123456789012:role/example-cicd-deployment-agent@cicd"  
cicd_external_id = <sensitive>
monitoring_role_arn = "arn:aws:iam::123456789012:role/example-monitoring-prometheus-collector@monitoring"
```

## Troubleshooting

### Common Issues

1. **"Access Denied" when assuming cross-account role**:
   - Verify the target account role trust policy includes your source role ARN
   - Check that external IDs match between source and target

2. **"Invalid external ID"**:
   - Ensure the external ID in the target account trust policy matches the one from Terraform outputs

3. **Pod Identity association not found**:
   - Verify EKS cluster name is correct
   - Ensure Pod Identity is enabled on your EKS cluster

### Validation Commands

```bash
# Test cross-account role assumption
aws sts assume-role \
  --role-arn "arn:aws:iam::TARGET-ACCOUNT:role/TARGET-ROLE" \
  --role-session-name "test-session" \
  --external-id "YOUR-EXTERNAL-ID"

# List Pod Identity associations
aws eks list-pod-identity-associations --cluster-name YOUR-CLUSTER
```

## Clean Up

To remove all resources:

```bash
terraform destroy
```

Note: This will not remove the target account roles - those need to be cleaned up separately in each target account.