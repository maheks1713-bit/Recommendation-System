# SmartPicks — Serverless Recommendation Engine

A serverless product recommendation backend built on AWS Lambda, API Gateway,
DynamoDB, S3, and EventBridge Scheduler. Combines a collaborative-filtering
signal (co-purchase counts) with a content-based signal (shared product
category) to generate personalized top-N recommendations per user, without
requiring a hosted ML service.

## Architecture Summary

```
                POST /events                GET /recommendations/{userId}
                     |                                  |
                     v                                  v
              +-------------+                   +----------------+
Client -----> | API Gateway | ----------------->| API Gateway    |
              +-------------+                   +----------------+
                     |                                  |
                     v                                  v
             +--------------+                  +------------------+
             | Ingest Lambda|                  | Recommend Lambda |
             +--------------+                  +------------------+
              |          |                              |
              v          v                               v
     +----------------+ +-----------------+    +----------------------+
     | DynamoDB:      | | S3:             |    | DynamoDB:            |
     | UserEvents     | | EventArchive    |    | RecommendationCache  |
     +----------------+ +-----------------+    +----------------------+
              ^                                          ^
              |                                          |
              |            +--------------------+        |
              +------------| Recompute Lambda   |--------+
                           +--------------------+
                                     ^
                                     |
                          +----------------------+
                          | EventBridge Scheduler|
                          | (nightly cron)       |
                          +----------------------+
```

**Data flow for a recommendation request:**
1. Client calls `GET /recommendations/{userId}`.
2. API Gateway (HTTP API, AWS_PROXY integration) invokes the Recommend Lambda.
3. Recommend Lambda reads the precomputed entry from the `RecommendationCache`
   DynamoDB table (a single `GetItem`, keeping p99 latency low) and returns
   the top-N product IDs as JSON.
4. If no entry exists (cold start), an empty list with an explanatory note
   is returned instead of an error.

**Data flow for the nightly batch job:**
1. EventBridge Scheduler triggers the Recompute Lambda at 03:00 UTC daily.
2. Recompute Lambda scans `UserEvents` and the `ProductCatalog` table.
3. Pure scoring logic (`lambda/recompute/scoring.py`, unit tested in
   `tests/test_scoring.py`) computes a co-purchase matrix and a
   content-based category-affinity boost, then ranks candidates per user.
4. Results are written to `RecommendationCache` for fast reads.

## Why no SageMaker (AI service trade-off)

AWS Academy Learner Lab's IAM policies denied `iam:GetPolicy` and
`datazone:ListDomains` when attempting to provision a SageMaker Unified
Studio domain, and the lab's `LabRole`-only IAM model makes it infeasible to
create/pass a dedicated SageMaker execution role. In production, the
Recompute Lambda's scoring logic would be replaced by a SageMaker Processing
job (for scheduled batch scoring) or a Bedrock-based embedding similarity
model (for semantic content-based matching) — see the report's Tech Stack
Justification section for the full trade-off discussion.

## Prerequisites

- Terraform >= 1.5.0
- Python 3.12
- An AWS Academy Learner Lab session (or any AWS account) with:
  - A pre-existing execution role (`LabRole` in Academy; any Lambda-capable
    role elsewhere) — this project **never creates IAM roles or policies**,
    it only references an existing role's ARN.
- AWS CLI configured with temporary credentials from your Learner Lab
  session (Academy > AWS Details > AWS CLI tab > copy credentials into
  `~/.aws/credentials`).

## Local Deployment

```bash
# 1. Clone and enter the repo
git clone <your-repo-url>
cd smartpicks

# 2. Configure Terraform variables
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Edit terraform.tfvars and set lab_role_arn to your LabRole ARN
# (IAM console -> Roles -> LabRole -> copy ARN)

# 3. Deploy infrastructure
cd terraform
terraform init
terraform plan
terraform apply

# 4. Note the api_endpoint output, then seed sample data
cd ..
python scripts/seed_data.py \
  --catalog-table smartpicks-product-catalog-staging \
  --events-table smartpicks-user-events-staging \
  --region us-east-1

# 5. Manually invoke the recompute Lambda once (or wait for the nightly
#    schedule) so RecommendationCache is populated:
aws lambda invoke --function-name smartpicks-recompute-staging /tmp/out.json

# 6. Test the API
curl https://<api_endpoint>/recommendations/user1
curl -X POST https://<api_endpoint>/events \
  -H "Content-Type: application/json" \
  -d '{"userId":"user6","productId":"p3","eventType":"purchase"}'
```

## Running Tests

```bash
pip install pytest boto3
python -m pytest tests/ -v
```

## CI/CD

GitHub Actions (`.github/workflows/deploy.yml`) runs on every push/PR:
1. **test** — unit tests against the pure scoring logic (no AWS calls needed)
2. **plan** (on PRs) — `terraform plan` against the Learner Lab account
3. **deploy** (on merge to `main`) — `terraform apply -auto-approve`

Required GitHub repo secrets:
- `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN` — from
  your Learner Lab session's AWS CLI credentials
- `LAB_ROLE_ARN` — your `LabRole` ARN

**Known lab constraint:** AWS Academy Learner Lab credentials are temporary
and expire when the lab session ends (typically a few hours), and rotate
every time you restart the lab. This means the GitHub secrets above must be
refreshed manually before each demo/CI run — a production AWS account would
instead use long-lived IAM roles via OIDC federation, removing this
maintenance burden entirely. This is discussed as an Operational Excellence
trade-off in the report.

## Project Structure

```
smartpicks/
├── terraform/              # All infrastructure as code
│   ├── main.tf              # Provider + backend config
│   ├── variables.tf
│   ├── dynamodb.tf
│   ├── s3.tf
│   ├── lambda.tf
│   ├── api_gateway.tf
│   ├── eventbridge.tf
│   └── outputs.tf
├── lambda/
│   ├── ingest/handler.py     # POST /events
│   ├── recompute/            # Nightly batch scoring
│   │   ├── handler.py
│   │   └── scoring.py        # Pure, unit-testable logic
│   └── recommend/handler.py  # GET /recommendations/{userId}
├── scripts/seed_data.py      # Demo data seeding
├── tests/test_scoring.py     # Unit tests
└── .github/workflows/deploy.yml
```