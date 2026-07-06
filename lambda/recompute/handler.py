"""
Recompute Lambda
-----------------
Triggered nightly by EventBridge Scheduler. Reads all recent user events
and the product catalog from DynamoDB, delegates scoring to the pure
scoring.build_recommendations() function (unit tested separately in
tests/test_scoring.py), then writes results to the RecommendationCache
table.

This intentionally avoids SageMaker: AWS Academy Learner Lab's IAM
restrictions (denied iam:GetPolicy / datazone:ListDomains, and PassRole
constraints for SageMaker execution roles) made provisioning a SageMaker
domain infeasible in the lab environment. In production, this batch
scoring job would be replaced by a SageMaker Processing job or a
Bedrock-backed embedding similarity model; that trade-off is discussed
in the accompanying report.

Env vars:
  USER_EVENTS_TABLE
  RECOMMENDATION_CACHE_TABLE
  PRODUCT_CATALOG_TABLE
"""
import os
import boto3

from scoring import build_recommendations

dynamodb = boto3.resource("dynamodb")

USER_EVENTS_TABLE = os.environ["USER_EVENTS_TABLE"]
RECOMMENDATION_CACHE_TABLE = os.environ["RECOMMENDATION_CACHE_TABLE"]
PRODUCT_CATALOG_TABLE = os.environ["PRODUCT_CATALOG_TABLE"]

events_table = dynamodb.Table(USER_EVENTS_TABLE)
cache_table = dynamodb.Table(RECOMMENDATION_CACHE_TABLE)
catalog_table = dynamodb.Table(PRODUCT_CATALOG_TABLE)


def handler(event, context):
    events = _scan_all(events_table)
    catalog = {item["productId"]: item for item in _scan_all(catalog_table)}

    recommendations = build_recommendations(events, catalog)

    for user_id, ranked in recommendations.items():
        cache_table.put_item(
            Item={
                "userId": user_id,
                "recommendations": [pid for pid, _ in ranked],
                "scores": {pid: str(score) for pid, score in ranked},
            }
        )

    return {"usersProcessed": len(recommendations)}


def _scan_all(table):
    items = []
    resp = table.scan()
    items.extend(resp.get("Items", []))
    while "LastEvaluatedKey" in resp:
        resp = table.scan(ExclusiveStartKey=resp["LastEvaluatedKey"])
        items.extend(resp.get("Items", []))
    return items
