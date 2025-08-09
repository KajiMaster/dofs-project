import json
import os
from typing import Dict, Any
from datetime import datetime

import boto3


dynamodb = boto3.resource("dynamodb")


def handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    DLQ Handler Lambda for DOFS
    - Triggered by SQS DLQ events
    - Persists failed order messages into the failed_orders DynamoDB table
    """

    failed_table_name = os.environ.get("FAILED_ORDERS_TABLE_NAME")
    if not failed_table_name:
        print("FAILED_ORDERS_TABLE_NAME env var is not set")
        return {"statusCode": 500, "message": "Configuration error"}

    failed_table = dynamodb.Table(failed_table_name)

    results = []
    try:
        for record in event.get("Records", []):
            try:
                body = json.loads(record.get("body", "{}"))
            except json.JSONDecodeError:
                body = {"raw_body": record.get("body")}

            now_iso = datetime.utcnow().isoformat()

            item = {
                "order_id": body.get("order", {}).get("order_id", body.get("order_id", "unknown")),
                "failed_at": now_iso,
                "failure_source": "sqs-dlq",
                "original_message": body,
            }

            # Best-effort: include a reason if present
            if "error" in body:
                item["failure_reason"] = body["error"]

            failed_table.put_item(Item=item)
            results.append({"status": "stored", "order_id": item["order_id"]})

        return {"statusCode": 200, "results": results}

    except Exception as exc:
        print(f"DLQ handler error: {str(exc)}")
        return {"statusCode": 500, "message": str(exc)}


