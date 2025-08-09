import json
import os
from typing import Dict, Any

def handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Validator Lambda function for DOFS Order Processing System
    Validates order structure and business rules
    """
    
    try:
        print(f"Validator received event: {json.dumps(event)}")
        
        # Extract order data from Step Functions input
        order_data = event.get('order', {})
        
        if not order_data:
            return {
                'statusCode': 400,
                'error': 'No order data provided',
                'validation_result': 'FAILED'
            }
        
        # Validate required fields
        required_fields = ['order_id', 'customer_id', 'items']
        for field in required_fields:
            if field not in order_data:
                return {
                    'statusCode': 400,
                    'error': f'Missing required field: {field}',
                    'validation_result': 'FAILED'
                }
        
        # Validate customer_id format
        customer_id = order_data.get('customer_id', '')
        if not customer_id or len(customer_id) < 3:
            return {
                'statusCode': 400,
                'error': 'Invalid customer_id format',
                'validation_result': 'FAILED'
            }
        
        # Validate items array
        items = order_data.get('items', [])
        if not isinstance(items, list) or len(items) == 0:
            return {
                'statusCode': 400,
                'error': 'Items must be a non-empty array',
                'validation_result': 'FAILED'
            }
        
        # Validate each item
        for i, item in enumerate(items):
            if not isinstance(item, dict):
                return {
                    'statusCode': 400,
                    'error': f'Item {i} must be an object',
                    'validation_result': 'FAILED'
                }
            
            if 'product_id' not in item or 'quantity' not in item:
                return {
                    'statusCode': 400,
                    'error': f'Item {i} missing product_id or quantity',
                    'validation_result': 'FAILED'
                }
            
            if not isinstance(item['quantity'], int) or item['quantity'] <= 0:
                return {
                    'statusCode': 400,
                    'error': f'Item {i} quantity must be a positive integer',
                    'validation_result': 'FAILED'
                }
        
        # Business rule validations
        total_quantity = sum(item['quantity'] for item in items)
        if total_quantity > 100:
            return {
                'statusCode': 400,
                'error': 'Order total quantity cannot exceed 100 items',
                'validation_result': 'FAILED'
            }
        
        print(f"Order {order_data['order_id']} validation successful")
        
        return {
            'statusCode': 200,
            'order': order_data,
            'validation_result': 'PASSED',
            'message': 'Order validation successful'
        }
        
    except Exception as e:
        print(f"Validation error: {str(e)}")
        return {
            'statusCode': 500,
            'error': f'Validation failed: {str(e)}',
            'validation_result': 'FAILED'
        }