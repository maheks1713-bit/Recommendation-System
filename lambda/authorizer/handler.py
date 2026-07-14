"""
Authorizer Lambda
------------------
REQUEST authorizer for API Gateway HTTP API. Validates the `x-api-key`
header against a shared secret and returns the HTTP API v2 simple
response format.

Env vars:
  API_KEY - shared secret clients must send as the x-api-key header
"""
import os

API_KEY = os.environ["API_KEY"]


def handler(event, context):
    headers = event.get("headers") or {}
    supplied_key = headers.get("x-api-key")

    return {"isAuthorized": supplied_key == API_KEY}
