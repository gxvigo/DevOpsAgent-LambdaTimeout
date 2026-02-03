# Quote of the Day - Cross-Account AWS Architecture

A serverless application that delivers personalized inspirational quotes using AWS Lambda, DynamoDB, and API Gateway across two AWS accounts.

## Overview

This project demonstrates a cross-account AWS architecture where:
- **Account One** hosts the quote database (DynamoDB) and retrieval service
- **Account Two** hosts the public API that personalizes quotes with user names

When a user calls the API with their name, the system generates a random number (1-10), retrieves a corresponding quote from the database in another AWS account, and returns a personalized message.

## Architecture

```
User Request → API Gateway (Account Two) 
              ↓
         NameHandler Lambda (Account Two)
              ↓ [Cross-Account Invocation]
         GetQuote Lambda (Account One)
              ↓
         DynamoDB Quotes Table (Account One)
```

## Features

- **Cross-Account Lambda Invocation**: Secure communication between Lambda functions in different AWS accounts
- **Auto-Initialization**: DynamoDB table automatically populates with quotes on first use
- **Random Quote Selection**: Each request gets a random quote from 10 inspirational messages
- **Personalized Messages**: Combines user's name with the quote of the day
- **Serverless Architecture**: No servers to manage, pay only for what you use
- **CloudWatch Monitoring**: Built-in alarms and logging for both Lambda functions

## Components

### Account One (acc-one-template.yaml)
- **DynamoDB Table**: `Quotes` table with 11 items (id 0-10)
- **GetQuote Lambda**: Retrieves quotes by number and handles table initialization
- **IAM Permissions**: Allows Account Two to invoke the Lambda function

### Account Two (acc-two-template.yaml)
- **NameHandler Lambda**: Orchestrates the quote retrieval process
- **API Gateway**: Public REST API endpoint at `/quote`
- **CloudWatch Alarm**: Monitors Lambda errors
- **DevOps Agent Trigger Lambda**: Triggers DevOps Agent investigations via webhook at `/trigger-investigation`

## Quick Start

See [DEPLOYMENT.md](DEPLOYMENT.md) for detailed deployment instructions.

### Prerequisites
- AWS CLI configured
- Access to two AWS accounts
- IAM permissions to create CloudFormation stacks (see IAM policy files)

### Manual Deployment

1. Deploy to Account One:
```bash
aws cloudformation deploy \
  --template-file acc-one-template.yaml \
  --stack-name quote-of-day-acc-one \
  --parameter-overrides AccountTwoId=<ACCOUNT_TWO_ID> \
  --capabilities CAPABILITY_IAM
```

2. Get the Lambda ARN from Account One outputs

3. Deploy to Account Two:
```bash
aws cloudformation deploy \
  --template-file acc-two-template.yaml \
  --stack-name quote-of-day-acc-two \
  --parameter-overrides AccountOneQuoteFunctionArn=<LAMBDA_ARN> \
  --capabilities CAPABILITY_IAM
```

### Automated Deployment with GitHub Actions

Two GitHub Actions workflows are provided for CI/CD:

- `.github/workflows/aws-accone.yml` - Deploys to Account One
- `.github/workflows/aws-acctwo.yml` - Deploys to Account Two

**Important**: These workflows contain hardcoded values that you must update for your environment:
- Account IDs (currently set to 757934432864 and 639930233929)
- Lambda Function ARN (currently set to arn:aws:lambda:ap-southeast-2:757934432864:function:GetQuoteFunction)
- AWS Region (currently set to ap-southeast-2)

**Required GitHub Secrets:**

For Account One workflow:
- `AWS_ACCESS_KEY_ID_ACC_ONE` - AWS access key for Account One
- `AWS_SECRET_ACCESS_KEY_ACC_ONE` - AWS secret key for Account One
- `ACCOUNT_TWO_ID` - Account Two ID (e.g., 639930233929)

For Account Two workflow:
- `AWS_ACCESS_KEY_ID_ACC_TWO` - AWS access key for Account Two
- `AWS_SECRET_ACCESS_KEY_ACC_TWO` - AWS secret key for Account Two
- `ACCOUNT_ONE_QUOTE_FUNCTION_ARN` - GetQuote Lambda ARN from Account One

**Triggering Workflows:**
- Automatically: Push to main branch
- Manually: GitHub UI → Actions tab → Select workflow → Run workflow button

## Usage

Once deployed, call the API with a name parameter:

```bash
curl "https://YOUR_API_ID.execute-api.us-east-1.amazonaws.com/prod/quote?name=Giovanni"
```

Response:
```json
{
  "message": "Hello Giovanni. This is your quote for today: Don't think of cost. Think of value.",
  "quote_number": 3
}
```

Without a name parameter, it defaults to "Friend":
```bash
curl "https://YOUR_API_ID.execute-api.us-east-1.amazonaws.com/prod/quote"
```

### Triggering DevOps Agent Investigations

The system includes an endpoint to manually trigger DevOps Agent investigations:

```bash
curl -X POST "https://YOUR_API_ID.execute-api.us-east-1.amazonaws.com/prod/trigger-investigation" \
  -H "Content-Type: application/json" \
  -d '{
    "incidentId": "INC-12345",
    "action": "created",
    "priority": "HIGH",
    "title": "Lambda timeout detected",
    "description": "NameHandler Lambda is experiencing timeouts",
    "service": "quote-of-day",
    "data": {
      "errorCount": 5,
      "region": "ap-southeast-2"
    }
  }'
```

**Incident Schema:**
- `incidentId` (optional): Unique incident identifier (auto-generated if not provided)
- `action` (optional): `created`, `updated`, `closed`, or `resolved` (default: `created`)
- `priority` (optional): `CRITICAL`, `HIGH`, `MEDIUM`, `LOW`, or `MINIMAL` (default: `HIGH`)
- `title` (optional): Incident title (default: "Quote of the Day Service Issue")
- `description` (optional): Detailed description
- `service` (optional): Service name (default: "quote-of-day")
- `data` (optional): Additional incident data

Response:
```json
{
  "message": "DevOps Agent investigation triggered successfully",
  "incidentId": "INC-12345",
  "webhookStatus": 200
}
```

## The Quotes Collection

The system includes 10 inspirational quotes:

1. You cannot change what you refuse to confront.
2. Sometimes good things fall apart so better things can fall together.
3. Don't think of cost. Think of value.
4. Sometimes you need to distance yourself to see things clearly.
5. Too many people buy things they don't need with money they don't have to impress people they don't know. Read Rich Dad, Poor Dad.
6. No matter how many mistakes you make or how slow you progress, you are still way ahead of everyone who isn't trying.
7. If a person wants to be a part of your life, they will make an obvious effort to do so. Think twice before reserving a space in your heart for people who do not make an effort to stay.
8. Making one person smile can change the world – maybe not the whole world, but their world.
9. Saying someone is ugly doesn't make you any prettier.
10. The only normal people you know are the ones you don't know very well.

## How It Works

1. User makes GET request to `/quote?name=YourName`
2. API Gateway triggers NameHandler Lambda in Account Two
3. NameHandler generates random number (1-10)
4. NameHandler invokes GetQuote Lambda in Account One with the number
5. GetQuote checks if DynamoDB table is initialized
6. If not initialized, loads all 10 quotes (plus control record)
7. GetQuote retrieves the quote for the given number
8. NameHandler combines name and quote into personalized message
9. Response returned to user

## Testing Timeout Behavior

The NameHandler Lambda includes a configurable timeout feature for testing error handling:

```bash
# Cause the function to timeout (set TIMEOUT > 5 seconds)
aws lambda update-function-configuration \
  --function-name NameHandlerFunction \
  --environment Variables={QUOTE_FUNCTION_ARN=<YOUR_ARN>,TIMEOUT=6} \
  --region ap-southeast-2

# Restore normal operation (set TIMEOUT to 0)
aws lambda update-function-configuration \
  --function-name NameHandlerFunction \
  --environment Variables={QUOTE_FUNCTION_ARN=<YOUR_ARN>,TIMEOUT=0} \
  --region ap-southeast-2
```

When TIMEOUT is set to 6, the function sleeps for 6 seconds, exceeding the 5-second Lambda timeout and triggering a failure. This is useful for testing CloudWatch alarms and error handling.

## Monitoring

Both Lambda functions log to CloudWatch Logs:
- `/aws/lambda/GetQuoteFunction` (Account One)
- `/aws/lambda/NameHandlerFunction` (Account Two)

CloudWatch Alarm triggers when NameHandler Lambda has >3 errors per minute.

## Security

- Cross-account access uses IAM roles and resource-based policies
- Lambda functions follow principle of least privilege
- DynamoDB uses on-demand billing mode
- API Gateway endpoint is public (add authentication for production)

## Cost Optimization

- DynamoDB: Pay-per-request billing (no provisioned capacity)
- Lambda: Pay only for invocations and compute time
- API Gateway: Pay per API call
- Estimated cost: <$1/month for low-volume usage

## Cleanup

Delete stacks in reverse order:

```bash
# Delete Account Two first
aws cloudformation delete-stack --stack-name quote-of-day-acc-two

# Then delete Account One
aws cloudformation delete-stack --stack-name quote-of-day-acc-one
```

## Files

- `acc-one-template.yaml` - CloudFormation template for Account One
- `acc-two-template.yaml` - CloudFormation template for Account Two
- `DEPLOYMENT.md` - Detailed deployment guide
- `iam-deployment-policy-acc-one.json` - IAM policy for Account One deployment
- `iam-deployment-policy-acc-two.json` - IAM policy for Account Two deployment
- `.github/workflows/aws-accone.yml` - GitHub Actions workflow for Account One
- `.github/workflows/aws-acctwo.yml` - GitHub Actions workflow for Account Two
- `template.yaml` - Legacy echo API template (deprecated)

## DevOps Agent Integration

The system includes integration with AWS DevOps Agent for automated incident investigation:

- **Webhook Endpoint**: Configured in `DevOpsAgentTriggerFunction`
- **Authentication**: HMAC-SHA256 signature using shared secret
- **Use Case**: Automatically trigger investigations when CloudWatch alarms fire or manual incident reporting

The webhook URL and secret are stored as Lambda environment variables and can be updated without redeploying the stack.

## License

This project is provided as-is for educational and demonstration purposes. 