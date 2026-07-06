"""
Pure scoring logic, deliberately separated from handler.py so it has no
dependency on boto3/AWS and can be unit tested in CI without mocking AWS
resources or requiring live credentials.
"""
from collections import defaultdict

TOP_N = 5


def build_recommendations(events, catalog, top_n=TOP_N):
    """
    events: list of dicts with keys userId, productId, eventType
    catalog: dict of productId -> {category, ...}
    returns: dict of userId -> list of (productId, score) tuples, sorted desc
    """
    user_purchases = defaultdict(set)
    for e in events:
        if e.get("eventType") == "purchase":
            user_purchases[e["userId"]].add(e["productId"])

    product_copurchases = defaultdict(lambda: defaultdict(int))
    for products in user_purchases.values():
        products = list(products)
        for i in range(len(products)):
            for j in range(len(products)):
                if i != j:
                    product_copurchases[products[i]][products[j]] += 1

    results = {}
    for user_id, purchased in user_purchases.items():
        scores = defaultdict(float)

        for p in purchased:
            for other_product, count in product_copurchases.get(p, {}).items():
                if other_product not in purchased:
                    scores[other_product] += count

        purchased_categories = {
            catalog[p]["category"] for p in purchased if p in catalog and "category" in catalog[p]
        }
        for product_id, meta in catalog.items():
            if product_id in purchased:
                continue
            if meta.get("category") in purchased_categories:
                scores[product_id] += 0.5

        ranked = sorted(scores.items(), key=lambda kv: kv[1], reverse=True)[:top_n]
        results[user_id] = ranked

    return results
