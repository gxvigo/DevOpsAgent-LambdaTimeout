# AWS CodePipeline Setup Guide

This guide explains how to set up AWS CodePipeline for automated cross-account deployment of the Quote of the Day application.

## Architecture Overview

```
GitHub Repository (Source)
         ↓
   CodePipeline (Account Two)
         ↓
    ┌────────────────────┐
    │  Stage 1: Deploy   │
    │  to Account One    │ → DynamoDB + GetQuote Lambda
    │  (Cross-Account)   │
    └────────────────────┘
         ↓ (Lambda ARN)
    ┌────────────────────┐
    │  Stage 2: Deploy   │
    │  to Account Two    │ → API Gateway + NameHandler Lambda
    │  (Local)           │
    └────────────────────┘
```

## Prerequisites

1. **GitHub Personal Access Token**
   - Go to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
   - Generate new token with `repo` and `admin:repo_hook` permissions
   - Save the token securely

2. **AWS CLI configured** for both accounts

3. **Account IDs**:
   - Account One: 757934432864
   - Account Two: 639930233929

## Step-by-Step Setup

### Step 1: Deploy Cross-Account Roles in Account One

First, create the IAM roles in Account One that allow CodePipeline from Account Two to deploy resources.

```bash
# Switch to Account One credentials
export AWS_PROFILE=account-one

# Deploy the cross-account role stack
aws cloudformation deploy \
  --template-file cross-account-role-template.yaml \
  --stack-name quote-of-day-cross-account-roles \
  --parameter-overrides \
    AccountTwoId=639930233929 \
    ArtifactBucketName=quote-of-day-pipeline-artifacts-639930233929 \
  --capabilities CAPABILITY_NAMED_IAM \
  --region ap-southeast-2

# Get the role ARNs (you'll need these for verification)
aws cloudformation describe-stacks \
  --stack-name quote-of-day-cross-account-roles \
  --query 'Stacks[0].Outputs' \
  --region ap-southeast-2
```

This creates:
- `QuoteOfDay-CrossAccountDeploymentRole` - Allows CodePipeline to deploy
- `QuoteOfDay-CloudFormationRole-AccOne` - Executes CloudFormation in Account One

### Step 2: Deploy CodePipeline in Account Two

Now deploy the pipeline infrastructure in Account Two.

```bash
# Switch to Account Two credentials
export AWS_PROFILE=account-two

# Store your GitHub token as a parameter (more secure than passing directly)
aws ssm put-parameter \
  --name /QuoteOfDay/GitHubToken \
  --value "YOUR_GITHUB_TOKEN" \
  --type SecureString \
  --region ap-southeast-2

# Get the token for deployment
GITHUB_TOKEN=$(aws ssm get-parameter \
  --name /QuoteOfDay/GitHubToken \
  --with-decryption \
  --query 'Parameter.Value' \
  --output text \
  --region ap-southeast-2)

# Deploy the pipeline stack
aws cloudformation deploy \
  --template-file pipeline-template.yaml \
  --stack-name quote-of-day-pipeline \
  --parameter-overrides \
    GitHubRepo=gxvigo/DevOpsAgent-LambdaTimeout \
    GitHubBranch=main \
    GitHubToken=${GITHUB_TOKEN} \
    AccountOneId=757934432864 \
    AccountTwoId=639930233929 \
  --capabilities CAPABILITY_NAMED_IAM \
  --region ap-southeast-2

# Get the pipeline URL
aws cloudformation describe-stacks \
  --stack-name quote-of-day-pipeline \
  --query 'Stacks[0].Outputs[?OutputKey==`PipelineUrl`].OutputValue' \
  --output text \
  --region ap-southeast-2
```

### Step 3: Verify Pipeline Setup

1. **Check Pipeline Status**:
```bash
aws codepipeline get-pipeline-state \
  --name QuoteOfDay-Pipeline \
  --region ap-southeast-2
```

2. **View in Console**:
   - Go to AWS Console → CodePipeline → Pipelines
   - Click on `QuoteOfDay-Pipeline`
   - You should see three stages: Source, DeployAccountOne, DeployAccountTwo

3. **Trigger First Deployment**:
   - The pipeline will automatically trigger on the next push to the main branch
   - Or manually release a change from the console

### Step 4: Monitor Deployment

Watch the pipeline execution:

```bash
# Get latest execution
aws codepipeline list-pipeline-executions \
  --pipeline-name QuoteOfDay-Pipeline \
  --max-items 1 \
  --region ap-southeast-2

# View CloudWatch Logs for detailed information
aws logs tail /aws/codepipeline/QuoteOfDay-Pipeline --follow --region ap-southeast-2
```

## How It Works

### Stage 1: Source
- Monitors GitHub repository for changes
- Triggers on push to main branch
- Downloads source code to S3 artifact bucket

### Stage 2: Deploy to Account One
1. CodePipeline assumes `QuoteOfDay-CrossAccountDeploymentRole` in Account One
2. Creates/updates CloudFormation stack `quote-of-day-acc-one`
3. CloudFormation uses `QuoteOfDay-CloudFormationRole-AccOne` to create resources
4. Outputs Lambda ARN to `acc-one-outputs.json`

### Stage 3: Deploy to Account Two
1. Reads Lambda ARN from previous stage output
2. Creates/updates CloudFormation stack `quote-of-day-acc-two`
3. Uses local CloudFormation role
4. Deploys API Gateway and NameHandler Lambda

## Passing Outputs Between Stages

The pipeline automatically handles output passing:

1. **Account One Output**: CloudFormation stack outputs are saved to `acc-one-outputs.json`
2. **Account Two Input**: Currently hardcoded in pipeline template (line 234)

**To use dynamic outputs** (requires custom Lambda or script):
```json
"ParameterOverrides": {
  "Fn::GetParam": ["AccOneOutputs", "acc-one-outputs.json", "GetQuoteFunctionArn"]
}
```

For now, the Lambda ARN is hardcoded. To make it dynamic, you'd need to add a Lambda function that parses the output file.

## Updating the Pipeline

### Change Deployment Parameters

Edit `pipeline-template.yaml` and update the `ParameterOverrides` section:

```yaml
ParameterOverrides: !Sub |
  {
    "AccountTwoId": "${AccountTwoId}",
    "QuotesTableName": "Quotes",
    "GetQuoteFunctionName": "GetQuoteFunction"
  }
```

Then redeploy:
```bash
aws cloudformation deploy \
  --template-file pipeline-template.yaml \
  --stack-name quote-of-day-pipeline \
  --parameter-overrides GitHubToken=${GITHUB_TOKEN} \
  --capabilities CAPABILITY_NAMED_IAM \
  --region ap-southeast-2
```

### Force API Gateway Redeployment

Increment the `DeploymentVersion` parameter in the pipeline template (line 235):
```yaml
"DeploymentVersion": "v5"  # Change from v4 to v5
```

## Troubleshooting

### Pipeline Fails at DeployAccountOne

**Error**: "Access Denied" or "Cannot assume role"

**Solution**: Verify cross-account roles in Account One:
```bash
aws iam get-role \
  --role-name QuoteOfDay-CrossAccountDeploymentRole \
  --region ap-southeast-2
```

Check the trust policy allows Account Two to assume the role.

### Pipeline Fails at DeployAccountTwo

**Error**: "Parameter validation failed"

**Solution**: Check that the Lambda ARN is correct in the pipeline template.

### S3 Access Denied

**Error**: "Access Denied" when accessing artifact bucket

**Solution**: Verify bucket policy allows cross-account access:
```bash
aws s3api get-bucket-policy \
  --bucket quote-of-day-pipeline-artifacts-639930233929 \
  --region ap-southeast-2
```

### GitHub Connection Issues

**Error**: "Could not access repository"

**Solution**: 
1. Verify GitHub token has correct permissions
2. Check token hasn't expired
3. Update token in SSM Parameter Store:
```bash
aws ssm put-parameter \
  --name /QuoteOfDay/GitHubToken \
  --value "NEW_TOKEN" \
  --type SecureString \
  --overwrite \
  --region ap-southeast-2
```

## Best Practices

### Security
- ✅ Use SSM Parameter Store for GitHub token (SecureString)
- ✅ Enable S3 bucket encryption
- ✅ Use least-privilege IAM roles
- ✅ Enable CloudTrail for audit logging

### Reliability
- ✅ Enable S3 versioning for artifacts
- ✅ Use CloudFormation for infrastructure as code
- ✅ Sequential stages with dependencies

### Future Enhancements
- 🔄 Add manual approval gate before production deployment
- 🔄 Add CodeBuild stage for testing
- 🔄 Add SNS notifications for pipeline status
- 🔄 Implement blue/green deployment for API Gateway
- 🔄 Add separate pipelines for dev/staging/prod

## Cost Considerations

- **CodePipeline**: $1/month per active pipeline
- **S3 Storage**: ~$0.023/GB/month for artifacts
- **CloudFormation**: Free
- **Data Transfer**: Cross-account data transfer charges may apply

**Estimated monthly cost**: $2-5 for low-volume usage

## Cleanup

To remove the pipeline infrastructure:

```bash
# Delete pipeline in Account Two
aws cloudformation delete-stack \
  --stack-name quote-of-day-pipeline \
  --region ap-southeast-2

# Delete cross-account roles in Account One
aws cloudformation delete-stack \
  --stack-name quote-of-day-cross-account-roles \
  --region ap-southeast-2

# Delete artifact bucket (after pipeline is deleted)
aws s3 rb s3://quote-of-day-pipeline-artifacts-639930233929 --force --region ap-southeast-2

# Delete SSM parameter
aws ssm delete-parameter \
  --name /QuoteOfDay/GitHubToken \
  --region ap-southeast-2
```

## References

- [AWS CodePipeline Documentation](https://docs.aws.amazon.com/codepipeline/)
- [Cross-Account Deployments](https://docs.aws.amazon.com/codepipeline/latest/userguide/pipelines-create-cross-account.html)
- [CloudFormation Best Practices](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/best-practices.html)
