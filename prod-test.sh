#!/bin/bash

# Production Environment Test Script
# Tests the complete DOFS order processing system

API_URL="https://1rf9554xdi.execute-api.us-east-1.amazonaws.com/prod"
ENVIRONMENT="PRODUCTION"

echo "========================================="
echo "🚀 DOFS $ENVIRONMENT ENVIRONMENT TEST"
echo "========================================="
echo "API Endpoint: $API_URL"
echo "Test Started: $(date)"
echo ""

# Test counters
TOTAL_ORDERS=0
SUCCESSFUL_REQUESTS=0
FAILED_REQUESTS=0

# Function to send order
send_order() {
    local order_id=$1
    local customer_name="Customer-$order_id"
    local product="Product-$(($RANDOM % 10 + 1))"
    local quantity=$(($RANDOM % 5 + 1))
    echo "📦 Sending Order #$order_id..."
    
    # Create order payload matching API expectations
    ORDER_JSON=$(cat <<EOF
{
    "customer_id": "$customer_name",
    "items": [
        {
            "product_id": "$product",
            "quantity": $quantity
        }
    ]
}
EOF
)
    
    # Send POST request
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -d "$ORDER_JSON" \
        "$API_URL/order")
    
    # Parse response
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | head -n -1)
    
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "202" ]; then
        echo "✅ Order #$order_id: HTTP $HTTP_CODE - $BODY"
        SUCCESSFUL_REQUESTS=$((SUCCESSFUL_REQUESTS + 1))
    else
        echo "❌ Order #$order_id: HTTP $HTTP_CODE - $BODY"
        FAILED_REQUESTS=$((FAILED_REQUESTS + 1))
    fi
    
    TOTAL_ORDERS=$((TOTAL_ORDERS + 1))
    
    # Small delay to avoid overwhelming the system
    sleep 0.5
}

# Send test orders
echo "🎯 Testing with 30 orders..."
echo ""

for i in $(seq 1 30); do
    ORDER_ID="prod-$(date +%s)-$i"
    send_order $ORDER_ID
done

echo ""
echo "⏳ Waiting 15 seconds for order processing..."
sleep 15

echo ""
echo "========================================="
echo "📊 $ENVIRONMENT TEST RESULTS"
echo "========================================="
echo "Total Orders Sent: $TOTAL_ORDERS"
echo "Successful API Requests: $SUCCESSFUL_REQUESTS"
echo "Failed API Requests: $FAILED_REQUESTS"
echo "API Success Rate: $((SUCCESSFUL_REQUESTS * 100 / TOTAL_ORDERS))%"
echo ""
echo "Note: Individual order fulfillment success rate is ~70%"
echo "Check DynamoDB tables and CloudWatch logs for detailed processing results"
echo ""
echo "Test Completed: $(date)"
echo "========================================="