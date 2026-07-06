"""
Ingest Lambda
-------------
Receives a user interaction event (view / purchase / add-to-cart) via
API Gateway POST /events, writes it to DynamoDB for fast recent-event
lookups, and archives the raw event to S3 for durable, long-term storage.

Env vars:
  USER_EVENTS_TABLE   - DynamoDB table for recent events
  EVENT_ARCHIVE_BUCKET - S3 bucket for raw event archive
"""
import json
import os
import time
import uuid
import boto3

dynamodb = boto3.resource("dynamodb")
s3 = boto3.client("s3")

USER_EVENTS_TABLE = os.environ["USER_EVENTS_TABLE"]
EVENT_ARCHIVE_BUCKET = os.environ["EVENT_ARCHIVE_BUCKET"]

table = dynamodb.Table(USER_EVENTS_TABLE)

REQUIRED_FIELDS = {"userId", "productId", "eventType"}
VALID_EVENT_TYPES = {"view", "purchase", "add_to_cart"}


def handler(event, context):
    try:
        body = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return _response(400, {"error": "Invalid JSON body"})

    missing = REQUIRED_FIELDS - body.keys()
    if missing:
        return _response(400, {"error": f"Missing required fields: {sorted(missing)}"})

    if body["eventType"] not in VALID_EVENT_TYPES:
        return _response(400, {"error": f"eventType must be one of {sorted(VALID_EVENT_TYPES)}"})

    event_id = str(uuid.uuid4())
    timestamp = int(time.time())

    item = {
        "userId": body["userId"],
        "eventId": event_id,
        "productId": body["productId"],
        "eventType": body["eventType"],
        "timestamp": timestamp,
    }

    table.put_item(Item=item)

    s3_key = f"raw-events/{body['userId']}/{event_id}.json"
    s3.put_object(
        Bucket=EVENT_ARCHIVE_BUCKET,
        Key=s3_key,
        Body=json.dumps(item),
        ContentType="application/json",
    )

    return _response(201, {"eventId": event_id, "status": "recorded"})


def _response(status_code, body_dict):
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body_dict),
    }
