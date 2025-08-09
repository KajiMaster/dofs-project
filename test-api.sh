#!/bin/bash

# DOFS API Test Script
# Tests the Phase 2 API Gateway + Lambda integration

API_URL="https://abv6t4rdig.execute-api.us-east-1.amazonaws.com/dev/order"

echo "🚀 Testing DOFS Order Processing API"
echo "API Endpoint: $API_URL"
echo ""

# Test 1: Valid Order (Happy Path)
echo "📦 Test 1: Valid Order"
curl -X POST "$API_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "customer_id": "cust-12345",
    "items": [
      {
        "product_id": "prod-widget-001",
        "quantity": 2
      },
      {
        "product_id": "prod-gadget-002",
        "quantity": 1
      }
    ]
  }' | jq '.'

echo -e "\n" && sleep 2

# Test 2: Missing customer_id
echo "❌ Test 2: Missing customer_id (should fail)"
curl -X POST "$API_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "items": [
      {"product_id": "prod-001", "quantity": 1}
    ]
  }' | jq '.'

echo -e "\n" && sleep 2

# Test 3: Empty items array
echo "❌ Test 3: Empty items array (should fail)"
curl -X POST "$API_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "customer_id": "cust-123",
    "items": []
  }' | jq '.'

echo -e "\n" && sleep 2

# Test 4: Invalid quantity
echo "❌ Test 4: Invalid quantity (should fail)"
curl -X POST "$API_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "customer_id": "cust-123",
    "items": [
      {"product_id": "prod-001", "quantity": 0}
    ]
  }' | jq '.'

echo -e "\n" && sleep 2

# Test 5: Another valid order
echo "📦 Test 5: Another Valid Order"
curl -X POST "$API_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "customer_id": "cust-67890",
    "items": [
      {
        "product_id": "prod-book-123",
        "quantity": 5
      }
    ]
  }' | jq '.'

echo -e "\n"
echo "✅ Testing complete!"
echo ""
echo "📊 Check DynamoDB table 'dofs-dev-orders' to see stored orders"
echo "🔍 Check CloudWatch logs for Lambda function 'dofs-dev-api-handler' for detailed logs"