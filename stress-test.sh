#!/bin/bash

# DOFS Stress Test Script - Send 50+ orders to dev environment
# Tests the complete order processing pipeline with various scenarios

API_URL="https://oi5xhz2v9h.execute-api.us-east-1.amazonaws.com/dev"
TOTAL_ORDERS=60
CONCURRENT_REQUESTS=5
LOG_FILE="stress-test-$(date +%Y%m%d-%H%M%S).log"

echo "🚀 DOFS Stress Test Starting - $(date)" | tee $LOG_FILE
echo "📊 Target: $TOTAL_ORDERS orders with $CONCURRENT_REQUESTS concurrent requests" | tee -a $LOG_FILE
echo "🎯 API URL: $API_URL" | tee -a $LOG_FILE
echo "===========================================" | tee -a $LOG_FILE

# Test data templates
declare -a CUSTOMERS=("cust-retail-001" "cust-wholesale-002" "cust-enterprise-003" "cust-startup-004" "cust-nonprofit-005")
declare -a PRODUCTS=("prod-widget-001" "prod-gadget-002" "prod-device-003" "prod-service-004" "prod-premium-005")
declare -a QUANTITIES=(1 2 5 10 25)

# Counters
SUCCESS_COUNT=0
FAILURE_COUNT=0
ERROR_COUNT=0

# Function to send a single order
send_order() {
    local order_num=$1
    local customer=${CUSTOMERS[$((RANDOM % ${#CUSTOMERS[@]}))]}
    local product=${PRODUCTS[$((RANDOM % ${#PRODUCTS[@]}))]}
    local quantity=${QUANTITIES[$((RANDOM % ${#QUANTITIES[@]}))]}
    
    # Create order payload
    local payload=$(cat <<EOF
{
    "customer_id": "$customer",
    "items": [
        {
            "product_id": "$product",
            "quantity": $quantity
        }
    ]
}
EOF
)
    
    echo "📤 Order $order_num: $customer -> $product x$quantity" | tee -a $LOG_FILE
    
    # Send request and capture response
    local response=$(curl -s -w "\n%{http_code}\n" -X POST "$API_URL/order" \
        -H "Content-Type: application/json" \
        -d "$payload" 2>/dev/null)
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | head -n-1)
    
    # Parse response
    if [[ $http_code == "200" ]]; then
        local order_id=$(echo "$body" | jq -r '.order_id // empty' 2>/dev/null)
        if [[ -n "$order_id" && "$order_id" != "null" ]]; then
            echo "✅ Order $order_num SUCCESS: $order_id" | tee -a $LOG_FILE
            ((SUCCESS_COUNT++))
        else
            echo "⚠️  Order $order_num: HTTP 200 but no order_id" | tee -a $LOG_FILE
            echo "   Response: $body" | tee -a $LOG_FILE
            ((FAILURE_COUNT++))
        fi
    else
        echo "❌ Order $order_num FAILED: HTTP $http_code" | tee -a $LOG_FILE
        echo "   Response: $body" | tee -a $LOG_FILE
        ((ERROR_COUNT++))
    fi
}

# Function to run concurrent batch
run_batch() {
    local start_num=$1
    local batch_size=$2
    
    echo "🔄 Running batch: Orders $start_num-$((start_num + batch_size - 1))" | tee -a $LOG_FILE
    
    # Run orders in parallel
    for ((i=0; i<batch_size; i++)); do
        send_order $((start_num + i)) &
    done
    
    # Wait for all background jobs to complete
    wait
    echo "✅ Batch complete" | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
}

# Main execution
echo "🎬 Starting stress test execution..." | tee -a $LOG_FILE
START_TIME=$(date +%s)

# Process orders in batches to avoid overwhelming the system
for ((batch_start=1; batch_start<=TOTAL_ORDERS; batch_start+=CONCURRENT_REQUESTS)); do
    remaining=$((TOTAL_ORDERS - batch_start + 1))
    batch_size=$((remaining < CONCURRENT_REQUESTS ? remaining : CONCURRENT_REQUESTS))
    
    run_batch $batch_start $batch_size
    
    # Brief pause between batches to allow processing
    sleep 2
done

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Final results
echo "===========================================" | tee -a $LOG_FILE
echo "🏁 STRESS TEST COMPLETE - $(date)" | tee -a $LOG_FILE
echo "⏱️  Duration: ${DURATION}s" | tee -a $LOG_FILE
echo "📊 Results:" | tee -a $LOG_FILE
echo "   ✅ Successful orders: $SUCCESS_COUNT" | tee -a $LOG_FILE
echo "   ⚠️  Failed orders: $FAILURE_COUNT" | tee -a $LOG_FILE
echo "   ❌ Error orders: $ERROR_COUNT" | tee -a $LOG_FILE
echo "   📈 Success rate: $(( (SUCCESS_COUNT * 100) / TOTAL_ORDERS ))%" | tee -a $LOG_FILE
echo "   🚀 Orders per second: $(( SUCCESS_COUNT / (DURATION > 0 ? DURATION : 1) ))" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

# System monitoring suggestions
echo "🔍 To monitor system behavior:" | tee -a $LOG_FILE
echo "   aws dynamodb scan --table-name dofs-dev-orders --select COUNT" | tee -a $LOG_FILE
echo "   aws dynamodb scan --table-name dofs-dev-failed-orders --select COUNT" | tee -a $LOG_FILE
echo "   aws sqs get-queue-attributes --queue-url \$(aws sqs get-queue-url --queue-name dofs-dev-order-queue --query QueueUrl --output text) --attribute-names ApproximateNumberOfMessages" | tee -a $LOG_FILE

echo "📄 Full log saved to: $LOG_FILE"

# Exit with appropriate code
if [[ $ERROR_COUNT -gt 0 ]]; then
    exit 1
elif [[ $FAILURE_COUNT -gt 0 ]]; then
    exit 2
else
    exit 0
fi