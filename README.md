# Echo API with Lambda and CloudWatch Monitoring

This CloudFormation stack deploys an API Gateway endpoint backed by a Lambda function that echoes input strings.

## Features

- **API Gateway**: Public HTTP GET endpoint at `/echo`
- **Lambda Function**: Python 3.11 function that returns the input query parameter
- **Intentional Failures**: Lambda times out ~1 in 3 invocations (for testing)
- **CloudWatch Alarm**: Monitors for >10 errors per minute

## Deployment

```bash
aws cloudformation create-stack \
  --stack-name devops-agent-api-timeout \
  --template-body file://template.yaml \
  --capabilities CAPABILITY_IAM
```

```
Update existing stack:

bash
aws cloudformation update-stack \
  --stack-name devops-agent-api-timeout \
  --template-body file://template.yaml \
  --capabilities CAPABILITY_IAM
  ```

## Usage

After deployment, get the API endpoint:

```bash
aws cloudformation describe-stacks \
  --stack-name echo-api-stack \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiEndpoint`].OutputValue' \
  --output text
```

Test the API:

```bash
curl "https://YOUR_API_ID.execute-api.REGION.amazonaws.com/prod/echo?input=hello"
```

Expected response:
```json
{"echo": "hello"}
```

## Monitoring

The CloudWatch alarm will trigger when the Lambda function has more than 10 errors within a 1-minute period. You can view the alarm in the AWS Console under CloudWatch > Alarms.

## Cleanup

```bash
aws cloudformation delete-stack --stack-name echo-api-stack
```
