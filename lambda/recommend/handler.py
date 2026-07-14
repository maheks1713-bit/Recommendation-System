"""
Recommend Lambda
-----------------
Serves GET /recommendations/{userId}. Reads the precomputed
RecommendationCache table (populated nightly by the recompute Lambda) and
returns the top-N product recommendations. Falls back to an empty list
with a hint if the user has no purchase history yet (cold start).

Env vars:
  RECOMMENDATION_CACHE_TABLE
"""
import json
import os
import re
import boto3

dynamodb = boto3.resource("dynamodb")

RECOMMENDATION_CACHE_TABLE = os.environ["RECOMMENDATION_CACHE_TABLE"]
cache_table = dynamodb.Table(RECOMMENDATION_CACHE_TABLE)

ID_PATTERN = re.compile(r"^[A-Za-z0-9_-]{1,64}$")


def handler(event, context):
    path_params = event.get("pathParameters") or {}
    user_id = path_params.get("userId")

    if not user_id:
        return _response(400, {"error": "userId path parameter is required"})

    if not ID_PATTERN.match(user_id):
        return _response(400, {"error": "userId must match ^[A-Za-z0-9_-]{1,64}$"})

    result = cache_table.get_item(Key={"userId": user_id})
    item = result.get("Item")

    if not item:
        return _response(200, {
            "userId": user_id,
            "recommendations": [],
            "note": "No purchase history found yet (cold start). Showing no personalized results."
        })

    return _response(200, {
        "userId": user_id,
        "recommendations": item.get("recommendations", []),
        "scores": item.get("scores", {}),
    })


def _response(status_code, body_dict):
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body_dict),
    }
