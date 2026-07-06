"""
Seed script - populates the product catalog table and generates a handful
of sample purchase events so the recompute Lambda has something to work
with during your demo. Run this once after `terraform apply`, then
manually invoke (or wait for) the recompute Lambda before hitting
GET /recommendations/{userId}.

Usage:
    python scripts/seed_data.py \
        --catalog-table smartpicks-product-catalog-staging \
        --events-table smartpicks-user-events-staging \
        --region us-east-1
"""
import argparse
import time
import uuid
import boto3

SAMPLE_PRODUCTS = [
    {"productId": "p1", "name": "Wireless Mouse", "category": "electronics", "price": "25.00"},
    {"productId": "p2", "name": "Mechanical Keyboard", "category": "electronics", "price": "80.00"},
    {"productId": "p3", "name": "USB-C Hub", "category": "electronics", "price": "35.00"},
    {"productId": "p4", "name": "Yoga Mat", "category": "fitness", "price": "20.00"},
    {"productId": "p5", "name": "Resistance Bands", "category": "fitness", "price": "15.00"},
    {"productId": "p6", "name": "Water Bottle", "category": "fitness", "price": "18.00"},
    {"productId": "p7", "name": "Novel: Dune", "category": "books", "price": "12.00"},
    {"productId": "p8", "name": "Novel: Foundation", "category": "books", "price": "14.00"},
]

SAMPLE_PURCHASES = [
    ("user1", "p1"), ("user1", "p2"),
    ("user2", "p2"), ("user2", "p3"),
    ("user3", "p4"), ("user3", "p5"),
    ("user4", "p1"), ("user4", "p3"),
    ("user5", "p7"), ("user5", "p8"),
]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog-table", required=True)
    parser.add_argument("--events-table", required=True)
    parser.add_argument("--region", default="us-east-1")
    args = parser.parse_args()

    dynamodb = boto3.resource("dynamodb", region_name=args.region)
    catalog_table = dynamodb.Table(args.catalog_table)
    events_table = dynamodb.Table(args.events_table)

    for product in SAMPLE_PRODUCTS:
        catalog_table.put_item(Item=product)
    print(f"Seeded {len(SAMPLE_PRODUCTS)} products into {args.catalog_table}")

    for user_id, product_id in SAMPLE_PURCHASES:
        events_table.put_item(Item={
            "userId": user_id,
            "eventId": str(uuid.uuid4()),
            "productId": product_id,
            "eventType": "purchase",
            "timestamp": int(time.time()),
        })
    print(f"Seeded {len(SAMPLE_PURCHASES)} purchase events into {args.events_table}")


if __name__ == "__main__":
    main()
