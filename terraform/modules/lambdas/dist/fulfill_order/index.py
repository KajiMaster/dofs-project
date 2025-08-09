import json
import boto3
import os
import random
from datetime import datetime
from typing import Dict, Any

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb')

def handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Fulfillment Lambda function for DOFS Order Processing System
    Simulates order fulfillment with configurable success rate (default 70%)
    Updates order status or moves failed orders to failed_orders table
    """
    
    try:
        print(f"Fulfillment received event: {json.dumps(event)}")
        
        # Extract order data from Step Functions input or SQS message
        if 'Records' in event:
            # SQS trigger
            record = event['Records'][0]
            body = json.loads(record['body'])
            order_data = body.get('order', {})
        else:
            # Direct Step Functions trigger
            order_data = event.get('order', {})
        
        if not order_data:
            return {
                'statusCode': 400,
                'error': 'No order data provided',
                'fulfillment_result': 'FAILED'
            }
        
        order_id = order_data.get('order_id')
        if not order_id:
            return {
                'statusCode': 400,
                'error': 'No order_id provided',
                'fulfillment_result': 'FAILED'
            }
        
        # Get environment variables
        orders_table_name = os.environ.get('ORDERS_TABLE_NAME')
        failed_orders_table_name = os.environ.get('FAILED_ORDERS_TABLE_NAME')
        success_rate = float(os.environ.get('SUCCESS_RATE', '0.7'))
        
        if not orders_table_name or not failed_orders_table_name:
            return {
                'statusCode': 500,
                'error': 'Required table environment variables not set',
                'fulfillment_result': 'FAILED'
            }
        
        orders_table = dynamodb.Table(orders_table_name)
        failed_orders_table = dynamodb.Table(failed_orders_table_name)
        
        # Simulate fulfillment process with success rate
        fulfillment_successful = random.random() < success_rate
        current_time = datetime.utcnow().isoformat()
        
        if fulfillment_successful:
            # Update order status to FULFILLED
            try:
                response = orders_table.update_item(
                    Key={'order_id': order_id},
                    UpdateExpression='SET #status = :status, updated_at = :updated_at, fulfilled_at = :fulfilled_at',
                    ExpressionAttributeNames={
                        '#status': 'status'
                    },
                    ExpressionAttributeValues={
                        ':status': 'FULFILLED',
                        ':updated_at': current_time,
                        ':fulfilled_at': current_time
                    },
                    ReturnValues='ALL_NEW'
                )
                
                print(f"Order {order_id} fulfilled successfully")
                
                return {
                    'statusCode': 200,
                    'order': response['Attributes'],
                    'fulfillment_result': 'SUCCESS',
                    'message': f"Order {order_id} fulfilled successfully"
                }
                
            except Exception as e:
                error_msg = f"Failed to update order status: {str(e)}"
                print(error_msg)
                return {
                    'statusCode': 500,
                    'error': error_msg,
                    'fulfillment_result': 'FAILED'
                }
        
        else:
            # Fulfillment failed - move to failed orders table and mark as failed
            try:
                # Get the current order from orders table
                order_response = orders_table.get_item(Key={'order_id': order_id})
                
                if 'Item' not in order_response:
                    return {
                        'statusCode': 404,
                        'error': f"Order {order_id} not found",
                        'fulfillment_result': 'FAILED'
                    }
                
                order_item = order_response['Item']
                retry_count = int(order_item.get('retry_count', 0)) + 1
                
                # Create failed order record
                failed_order_item = {
                    **order_item,
                    'failed_at': current_time,
                    'failure_reason': 'Fulfillment simulation failed',
                    'retry_count': retry_count,
                    'original_order_id': order_id
                }
                
                # Store in failed orders table
                failed_orders_table.put_item(Item=failed_order_item)
                
                # Update original order status to FAILED
                orders_table.update_item(
                    Key={'order_id': order_id},
                    UpdateExpression='SET #status = :status, updated_at = :updated_at, failed_at = :failed_at, retry_count = :retry_count',
                    ExpressionAttributeNames={
                        '#status': 'status'
                    },
                    ExpressionAttributeValues={
                        ':status': 'FAILED',
                        ':updated_at': current_time,
                        ':failed_at': current_time,
                        ':retry_count': retry_count
                    }
                )
                
                print(f"Order {order_id} fulfillment failed, moved to failed orders table")
                
                return {
                    'statusCode': 200,
                    'order': failed_order_item,
                    'fulfillment_result': 'FAILED',
                    'message': f"Order {order_id} fulfillment failed"
                }
                
            except Exception as e:
                error_msg = f"Failed to handle order failure: {str(e)}"
                print(error_msg)
                return {
                    'statusCode': 500,
                    'error': error_msg,
                    'fulfillment_result': 'FAILED'
                }
        
    except Exception as e:
        error_msg = f"Fulfillment processing failed: {str(e)}"
        print(error_msg)
        return {
            'statusCode': 500,
            'error': error_msg,
            'fulfillment_result': 'FAILED'
        }