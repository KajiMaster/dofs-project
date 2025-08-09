import json
import boto3
import os
from datetime import datetime
from typing import Dict, Any

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb')

def handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Order Storage Lambda function for DOFS Order Processing System
    Stores validated orders in DynamoDB orders table
    """
    
    try:
        print(f"Order Storage received event: {json.dumps(event)}")
        
        # Extract order data from Step Functions input
        order_data = event.get('order', {})
        
        if not order_data:
            return {
                'statusCode': 400,
                'error': 'No order data provided',
                'storage_result': 'FAILED'
            }
        
        # Get table name from environment
        table_name = os.environ.get('ORDERS_TABLE_NAME')
        if not table_name:
            return {
                'statusCode': 500,
                'error': 'ORDERS_TABLE_NAME environment variable not set',
                'storage_result': 'FAILED'
            }
        
        table = dynamodb.Table(table_name)
        
        # Add metadata to order
        order_item = {
            **order_data,
            'status': 'PROCESSING',
            'created_at': datetime.utcnow().isoformat(),
            'updated_at': datetime.utcnow().isoformat(),
            'retry_count': 0
        }
        
        # Calculate total quantity for GSI
        if 'items' in order_item:
            order_item['total_quantity'] = sum(item.get('quantity', 0) for item in order_item['items'])
        
        # Store order in DynamoDB
        response = table.put_item(
            Item=order_item,
            ConditionExpression='attribute_not_exists(order_id)'
        )
        
        print(f"Order {order_data['order_id']} stored successfully")
        
        return {
            'statusCode': 200,
            'order': order_item,
            'storage_result': 'SUCCESS',
            'message': f"Order {order_data['order_id']} stored successfully"
        }
        
    except dynamodb.meta.client.exceptions.ConditionalCheckFailedException:
        error_msg = f"Order {order_data.get('order_id', 'unknown')} already exists"
        print(error_msg)
        return {
            'statusCode': 409,
            'error': error_msg,
            'storage_result': 'FAILED'
        }
        
    except Exception as e:
        error_msg = f"Order storage failed: {str(e)}"
        print(error_msg)
        return {
            'statusCode': 500,
            'error': error_msg,
            'storage_result': 'FAILED'
        }