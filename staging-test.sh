#!/bin/bash

# DOFS Staging Environment Test - 25 orders to validate deployment
API_URL="https://fuoz273tnl.execute-api.us-east-1.amazonaws.com/staging"
TOTAL_ORDERS=25
CONCURRENT_REQUESTS=3
LOG_FILE="staging-test-$(date +%Y%m%d-%H%M%S).log"

echo "🎭 DOFS Staging Test Starting - $(date)" | tee $LOG_FILE
echo "📊 Target: $TOTAL_ORDERS orders with $CONCURRENT_REQUESTS concurrent requests" | tee -a $LOG_FILE
echo "🎯 API URL: $API_URL" | tee -a $LOG_FILE
echo "===========================================" | tee -a $LOG_FILE

# Test data templates
declare -a CUSTOMERS=("cust-staging-001" "cust-staging-002" "cust-staging-003" "cust-staging-004" "cust-staging-005")
declare -a PRODUCTS=("prod-stage-widget" "prod-stage-gadget" "prod-stage-device" "prod-stage-service" "prod-stage-premium")
declare -a QUANTITIES=(1 3 5 10 15)

# Counters
SUCCESS_COUNT=0
TOTAL_SUBMITTED=0

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
    
    echo "📤 Staging Order $order_num: $customer -> $product x$quantity" | tee -a $LOG_FILE
    
    # Send request and capture response
    local response=$(curl -s -w "\n%{http_code}\n" -X POST "$API_URL/order" \
        -H "Content-Type: application/json" \
        -d "$payload" 2>/dev/null)
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | head -n-1)
    
    ((TOTAL_SUBMITTED++))
    
    # Parse response
    if [[ $http_code == "200" ]]; then
        local order_id=$(echo "$body" | jq -r '.order_id // empty' 2>/dev/null)
        if [[ -n "$order_id" && "$order_id" != "null" ]]; then
            echo "✅ Staging Order $order_num SUCCESS: $order_id" | tee -a $LOG_FILE
            ((SUCCESS_COUNT++))
        else
            echo "⚠️  Staging Order $order_num: HTTP 200 but no order_id" | tee -a $LOG_FILE
        fi
    else
        echo "❌ Staging Order $order_num FAILED: HTTP $http_code" | tee -a $LOG_FILE
        echo "   Response: $body" | tee -a $LOG_FILE
    fi
}

# Function to run concurrent batch
run_batch() {
    local start_num=$1
    local batch_size=$2
    
    echo "🔄 Running staging batch: Orders $start_num-$((start_num + batch_size - 1))" | tee -a $LOG_FILE
    
    # Run orders in parallel
    for ((i=0; i<batch_size; i++)); do
        send_order $((start_num + i)) &
    done
    
    # Wait for all background jobs to complete
    wait
    echo "✅ Staging batch complete" | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
}

# Main execution
echo "🎬 Starting staging test execution..." | tee -a $LOG_FILE
START_TIME=$(date +%s)

# Process orders in batches
for ((batch_start=1; batch_start<=TOTAL_ORDERS; batch_start+=CONCURRENT_REQUESTS)); do
    remaining=$((TOTAL_ORDERS - batch_start + 1))
    batch_size=$((remaining < CONCURRENT_REQUESTS ? remaining : CONCURRENT_REQUESTS))
    
    run_batch $batch_start $batch_size
    
    # Brief pause between batches
    sleep 2
done

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Final results
echo "===========================================" | tee -a $LOG_FILE
echo "🏁 STAGING TEST COMPLETE - $(date)" | tee -a $LOG_FILE
echo "⏱️  Duration: ${DURATION}s" | tee -a $LOG_FILE
echo "📊 Results:" | tee -a $LOG_FILE
echo "   📤 Total submitted: $TOTAL_SUBMITTED" | tee -a $LOG_FILE
echo "   ✅ Successful orders: $SUCCESS_COUNT" | tee -a $LOG_FILE
echo "   📈 Success rate: $(( (SUCCESS_COUNT * 100) / TOTAL_SUBMITTED ))%" | tee -a $LOG_FILE
echo "   🚀 Orders per second: $(( SUCCESS_COUNT / (DURATION > 0 ? DURATION : 1) ))" | tee -a $LOG_FILE

echo "📄 Staging test log saved to: $LOG_FILE"