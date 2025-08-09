import json
import uuid
import boto3
import os
from datetime import datetime
from typing import Dict, Any

# Initialize AWS clients
stepfunctions = boto3.client('stepfunctions')

def handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    API Handler Lambda function for DOFS Order Processing System
    Handles incoming POST requests to /order endpoint
    """
    
    try:
        # Log the incoming request
        print(f"Received event: {json.dumps(event)}")
        
        # Parse the request body
        if 'body' not in event or not event['body']:
            return create_response(400, {"error": "Request body is required"})
        
        try:
            body = json.loads(event['body'])
        except json.JSONDecodeError:
            return create_response(400, {"error": "Invalid JSON in request body"})
        
        # Validate required fields
        if 'customer_id' not in body or 'items' not in body:
            return create_response(400, {"error": "customer_id and items are required"})
        
        # Validate items structure
        if not isinstance(body['items'], list) or len(body['items']) == 0:
            return create_response(400, {"error": "items must be a non-empty array"})
        
        for item in body['items']:
            if not isinstance(item, dict) or 'product_id' not in item or 'quantity' not in item:
                return create_response(400, {"error": "Each item must have product_id and quantity"})
            if not isinstance(item['quantity'], int) or item['quantity'] < 1:
                return create_response(400, {"error": "quantity must be a positive integer"})
        
        # Generate order ID and timestamp
        order_id = str(uuid.uuid4())
        timestamp = datetime.utcnow().isoformat()
        
        # Create order object
        order = {
            'order_id': order_id,
            'customer_id': body['customer_id'],
            'items': body['items'],
            'timestamp': timestamp
        }
        
        # Get Step Function ARN from environment
        step_function_arn = os.environ.get('STEP_FUNCTION_ARN')
        if not step_function_arn:
            return create_response(500, {"error": "Step Function ARN not configured"})
        
        # Start Step Function execution
        try:
            execution_input = {
                'order': order,
                'timestamp': timestamp,
                'source': 'api-gateway'
            }
            
            execution_name = f"order-{order_id}-{int(datetime.utcnow().timestamp())}"
            
            response = stepfunctions.start_execution(
                stateMachineArn=step_function_arn,
                name=execution_name,
                input=json.dumps(execution_input)
            )
            
            print(f"Started Step Function execution for order {order_id}: {response['executionArn']}")
            
        except Exception as e:
            print(f"Failed to start Step Function execution for order {order_id}: {str(e)}")
            return create_response(500, {"error": "Failed to process order"})
        
        # Return success response
        response_body = {
            "message": "Order received and processing started",
            "order_id": order_id,
            "status": "processing",
            "execution_arn": response['executionArn']
        }
        
        return create_response(200, response_body)
        
    except Exception as e:
        print(f"Unexpected error: {str(e)}")
        return create_response(500, {"error": "Internal server error"})

def create_response(status_code: int, body: Dict[str, Any]) -> Dict[str, Any]:
    """
    Create a properly formatted API Gateway response
    """
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'POST',
            'Access-Control-Allow-Headers': 'Content-Type'
        },
        'body': json.dumps(body)
    }