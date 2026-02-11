#!/bin/bash

# Configuration
TARGET_ACCOUNT_ID="757934432864"
ROLE_NAME="CloudFormationDeployRole"
STACK_NAME="quote-of-the-day-manual-deployment"
REGION="ap-southeast-2"

# Assume the role in target account
CREDS=$(aws sts assume-role \
  --role-arn arn:aws:iam::${TARGET_ACCOUNT_ID}:role/${ROLE_NAME} \
  --role-session-name cfn-deploy \
  --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
  --output text)

export AWS_ACCESS_KEY_ID=$(echo $CREDS | awk '{print $1}')
export AWS_SECRET_ACCESS_KEY=$(echo $CREDS | awk '{print $2}')
export AWS_SESSION_TOKEN=$(echo $CREDS | awk '{print $3}')

# Deploy using assumed credentials
aws cloudformation deploy \
  --template-file acc-one-template.yaml \
  --stack-name $STACK_NAME \
  --parameter-overrides AccountTwoId=639930233929 \
  --region $REGION \
  --no-fail-on-empty-changeset \
  --capabilities CAPABILITY_NAMED_IAM

echo "Stack deployed to account $TARGET_ACCOUNT_ID"
