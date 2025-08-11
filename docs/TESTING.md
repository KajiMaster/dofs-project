# DOFS Testing Guide

Testing strategies and results for the Distributed Order Fulfillment System.

## Quick Start

Run environment-specific tests:
```bash
# Development environment
./stress-test.sh

# Staging environment  
./staging-test.sh

# Production environment
./prod-test.sh
```

## Test Results Summary

| Environment | Orders Tested | API Success Rate | Notes |
|-------------|---------------|------------------|--------|
| Dev | 60 | 100% | 73% fulfillment rate |
| Staging | 25 | 100% | 80% fulfillment rate |  
| Production | 30 | 100% | System fully operational |

## Key Features Verified

✅ **API Validation**: Two-tier validation (API Gateway + Lambda)  
✅ **Step Functions**: Error handling and sequential workflow  
✅ **DynamoDB**: Order storage and failed order tracking  
✅ **SQS**: Message processing with DLQ handling  
✅ **Error Handling**: Failed orders properly tracked

## Manual Testing

For detailed testing, use the provided scripts with environment-specific API URLs:

```bash
# Get environment URL
cd terraform/environments/multi-env
terraform workspace select <environment>
terraform output api_gateway_url

# Test API directly
curl -X POST <API_URL>/order \
  -H "Content-Type: application/json" \
  -d '{
    "customer_id": "test-customer",
    "items": [
      {"product_id": "widget-123", "quantity": 2}
    ]
  }'
```

## Expected Behavior

- **API Success Rate**: 100% for valid requests
- **Fulfillment Rate**: ~70% (configurable in tfvars)
- **Error Handling**: Failed orders tracked in `failed_orders` table
- **Queue Processing**: No message accumulation in DLQ