# Quote of the Day - Cross-Account Deployment Guide

This project implements a "Quote of the Day" system using AWS Lambda, DynamoDB, and API Gateway across two AWS accounts.

## Architecture

### Account One (acc-one) - 757934432864
- **DynamoDB Table**: Stores 10 inspirational quotes
- **GetQuote Lambda**: Retrieves quotes by number (1-10) and auto-initializes the table

### Account Two (acc-two) - 639930233929
- **NameHandler Lambda**: Accepts a name, generates random number (1-10), invokes GetQuote Lambda in Account One
- **API Gateway**: Public endpoint to access the service

## Prerequisites

- AWS CLI configured with credentials for both accounts
- Appropriate IAM permissions to create CloudFormation stacks
- Account IDs for both AWS accounts

## Deployment Steps

### Step 1: Deploy to Account One

First, deploy the DynamoDB and GetQuote Lambda function in Account One.

```bash
# Switch to Account One credentials
export AWS_PROFILE=account-one  # or use appropriate credential method

# Deploy the stack
aws cloudformation create-stack \
  --stack-name quote-of-day-acc-one \
  --template-body file://acc-one-template.yaml \
  --parameters ParameterKey=AccountTwoId,ParameterValue=639930233929 \
  --capabilities CAPABILITY_IAM \
  --region ap-southeast-2

# Wait for stack creation to complete
aws cloudformation wait stack-create-complete \
  --stack-name quote-of-day-acc-one \
  --region ap-southeast-2

# Get the Lambda function ARN (needed for Account Two)
aws cloudformation describe-stacks \
  --stack-name quote-of-day-acc-one \
  --query 'Stacks[0].Outputs[?OutputKey==`GetQuoteFunctionArn`].OutputValue' \
  --output text \
  --region ap-southeast-2
```

**Important**: Save the `GetQuoteFunctionArn` output - you'll need it for the next step.

### Step 2: Deploy to Account Two

Deploy the NameHandler Lambda and API Gateway in Account Two.

```bash
# Switch to Account Two credentials
export AWS_PROFILE=account-two  # or use appropriate credential method

# Deploy the stack (replace <GET_QUOTE_FUNCTION_ARN> with the ARN from Step 1)
aws cloudformation create-stack \
  --stack-name quote-of-day-acc-two \
  --template-body file://acc-two-template.yaml \
  --parameters ParameterKey=AccountOneQuoteFunctionArn,ParameterValue=arn:aws:lambda:ap-southeast-2:757934432864:function:GetQuoteFunction \
  --capabilities CAPABILITY_IAM \
  --region ap-southeast-2

# Wait for stack creation to complete
aws cloudformation wait stack-create-complete \
  --stack-name quote-of-day-acc-two \
  --region ap-southeast-2

# Get the API endpoint
aws cloudformation describe-stacks \
  --stack-name quote-of-day-acc-two \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiEndpoint`].OutputValue' \
  --output text \
  --region ap-southeast-2
```

## Testing

Once both stacks are deployed, test the API:

```bash
# Get your API endpoint from the output above
API_ENDPOINT="https://YOUR_API_ID.execute-api.ap-southeast-2.amazonaws.com/prod/quote"

# Test with a name
curl "${API_ENDPOINT}?name=Giovanni"

# Expected response:
# {
#   "message": "Hello Giovanni. This is your quote for today: Don't think of cost. Think of value.",
#   "quote_number": 3
# }

# Test without a name (defaults to "Friend")
curl "${API_ENDPOINT}"
```

## How It Works

1. User calls the API Gateway endpoint with a `name` query parameter
2. NameHandler Lambda in Account Two:
   - Receives the name
   - Generates a random number between 1-10
   - Invokes GetQuote Lambda in Account One with the number
3. GetQuote Lambda in Account One:
   - Checks if DynamoDB table is initialized (control record id=0)
   - If not initialized, loads all 10 quotes
   - Retrieves the quote for the given number
   - Returns the quote
4. NameHandler Lambda combines the name and quote into a personalized message
5. Returns the message to the user

## The 10 Quotes

0. CORRECT (control record)
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

## Updating Stacks

To update an existing stack after making changes to the templates:

### Update Account One Stack

```bash
# Switch to Account One credentials
export AWS_PROFILE=account-one

# Update the stack
aws cloudformation update-stack \
  --stack-name quote-of-day-acc-one \
  --template-body file://acc-one-template.yaml \
  --parameters ParameterKey=AccountTwoId,ParameterValue=639930233929 \
  --capabilities CAPABILITY_IAM \
  --region ap-southeast-2

# Wait for update to complete
aws cloudformation wait stack-update-complete \
  --stack-name quote-of-day-acc-one \
  --region ap-southeast-2
```

### Update Account Two Stack

```bash
# Switch to Account Two credentials
export AWS_PROFILE=account-two

# Update the stack
aws cloudformation update-stack \
  --stack-name quote-of-day-acc-two \
  --template-body file://acc-two-template.yaml \
  --parameters ParameterKey=AccountOneQuoteFunctionArn,ParameterValue=arn:aws:lambda:ap-southeast-2:757934432864:function:GetQuoteFunction \
  --capabilities CAPABILITY_IAM \
  --region ap-southeast-2

# Wait for update to complete
aws cloudformation wait stack-update-complete \
  --stack-name quote-of-day-acc-two \
  --region ap-southeast-2
```

### Quick Update Commands

If you just need the commands without switching profiles:

```bash
# Account One
aws cloudformation update-stack \
  --stack-name quote-of-day-acc-one \
  --template-body file://acc-one-template.yaml \
  --parameters ParameterKey=AccountTwoId,ParameterValue=<ACCOUNT_TWO_ID> \
  --capabilities CAPABILITY_IAM \
  --region ap-southeast-2

# Account Two
aws cloudformation update-stack \
  --stack-name quote-of-day-acc-two \
  --template-body file://acc-two-template.yaml \
  --parameters ParameterKey=AccountOneQuoteFunctionArn,ParameterValue=<GET_QUOTE_FUNCTION_ARN> \
  --capabilities CAPABILITY_IAM \
  --region ap-southeast-2
```

**Note**: Replace `<ACCOUNT_TWO_ID>` and `<GET_QUOTE_FUNCTION_ARN>` with your actual values if using the quick commands.

## Cleanup

To delete the stacks:

```bash
# Delete Account Two stack first
aws cloudformation delete-stack \
  --stack-name quote-of-day-acc-two \
  --region ap-southeast-2

# Wait for deletion
aws cloudformation wait stack-delete-complete \
  --stack-name quote-of-day-acc-two \
  --region ap-southeast-2

# Then delete Account One stack
aws cloudformation delete-stack \
  --stack-name quote-of-day-acc-one \
  --region ap-southeast-2

aws cloudformation wait stack-delete-complete \
  --stack-name quote-of-day-acc-one \
  --region ap-southeast-2
```

## Testing Timeout Behavior

The NameHandler Lambda function in Account Two includes a configurable timeout feature for testing error handling and monitoring.

### How It Works

- The Lambda has a **5-second timeout**
- The `TIMEOUT` environment variable controls sleep duration (default: 0 seconds)
- Setting `TIMEOUT` to a value greater than 5 will cause the function to timeout

### Simulate a Timeout Failure

To make the function fail due to timeout:

```bash
# Set TIMEOUT to 6 seconds (exceeds the 5-second Lambda timeout)
aws lambda update-function-configuration \
  --function-name NameHandlerFunction \
  --environment Variables={QUOTE_FUNCTION_ARN=arn:aws:lambda:ap-southeast-2:757934432864:function:GetQuoteFunction,TIMEOUT=6} \
  --region ap-southeast-2

# Wait a moment for the configuration to update
sleep 5

# Test the API - this should timeout
curl "https://YOUR_API_ID.execute-api.ap-southeast-2.amazonaws.com/prod/quote?name=Test"
```

The function will sleep for 6 seconds, exceeding the 5-second timeout, and you'll receive a timeout error. The CloudWatch alarm should trigger after multiple failures.

### Restore Normal Operation

To restore the function to normal operation:

```bash
# Set TIMEOUT back to 0 seconds
aws lambda update-function-configuration \
  --function-name NameHandlerFunction \
  --environment Variables={QUOTE_FUNCTION_ARN=arn:aws:lambda:ap-southeast-2:757934432864:function:GetQuoteFunction,TIMEOUT=0} \
  --region ap-southeast-2

# Test the API - should work normally
curl "https://YOUR_API_ID.execute-api.ap-southeast-2.amazonaws.com/prod/quote?name=Test"
```

### Using AWS Console

You can also change the TIMEOUT variable through the AWS Console:

1. Go to Lambda → Functions → NameHandlerFunction
2. Click on "Configuration" tab
3. Click on "Environment variables"
4. Edit the `TIMEOUT` variable (set to 6 to cause timeout, 0 for normal operation)
5. Save changes

## Troubleshooting

### Cross-Account Invocation Issues

If you get permission errors when invoking the Lambda:

1. Verify the Account Two ID is correct in the Account One stack parameters
2. Check that the GetQuote Lambda ARN is correct in the Account Two stack parameters
3. Ensure the IAM role in Account Two has permission to invoke Lambda in Account One
4. Check CloudWatch Logs for both Lambda functions

### DynamoDB Issues

If quotes aren't being retrieved:

1. Check CloudWatch Logs for the GetQuote Lambda
2. Verify the DynamoDB table was created in Account One
3. Check if the table was initialized (should have 11 items: id 0-10)

### Viewing Logs

```bash
# Account One - GetQuote Lambda logs
aws logs tail /aws/lambda/GetQuoteFunction --follow --region ap-southeast-2

# Account Two - NameHandler Lambda logs
aws logs tail /aws/lambda/NameHandlerFunction --follow --region ap-southeast-2
```

## Security Considerations

- The API Gateway endpoint is public (no authentication)
- Cross-account Lambda invocation uses IAM roles and permissions
- DynamoDB table uses PAY_PER_REQUEST billing mode
- Lambda functions have minimal IAM permissions (principle of least privilege)

For production use, consider:
- Adding API Gateway authentication (API keys, Cognito, IAM)
- Implementing rate limiting
- Adding WAF rules
- Encrypting DynamoDB table at rest
- Using VPC endpoints for private communication
