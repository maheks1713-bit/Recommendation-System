import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lambda", "recompute"))

from scoring import build_recommendations


CATALOG = {
    "p1": {"category": "electronics"},
    "p2": {"category": "electronics"},
    "p3": {"category": "electronics"},
    "p4": {"category": "fitness"},
    "p5": {"category": "fitness"},
}


def test_copurchase_signal_recommends_frequently_bought_together_item():
    events = [
        {"userId": "userA", "productId": "p1", "eventType": "purchase"},
        {"userId": "userA", "productId": "p2", "eventType": "purchase"},
        {"userId": "userB", "productId": "p1", "eventType": "purchase"},
        {"userId": "userB", "productId": "p2", "eventType": "purchase"},
        {"userId": "userC", "productId": "p1", "eventType": "purchase"},
    ]
    results = build_recommendations(events, CATALOG)

    # userC bought p1 only; since p1+p2 were co-purchased twice (userA, userB),
    # p2 should be userC's top recommendation.
    assert results["userC"][0][0] == "p2"


def test_content_based_signal_recommends_same_category():
    events = [
        {"userId": "userA", "productId": "p4", "eventType": "purchase"},
    ]
    results = build_recommendations(events, CATALOG)

    recommended_ids = [pid for pid, _ in results["userA"]]
    assert "p5" in recommended_ids  # same "fitness" category


def test_already_purchased_items_are_excluded():
    events = [
        {"userId": "userA", "productId": "p1", "eventType": "purchase"},
        {"userId": "userA", "productId": "p2", "eventType": "purchase"},
    ]
    results = build_recommendations(events, CATALOG)

    recommended_ids = [pid for pid, _ in results["userA"]]
    assert "p1" not in recommended_ids
    assert "p2" not in recommended_ids


def test_non_purchase_events_are_ignored():
    events = [
        {"userId": "userA", "productId": "p1", "eventType": "view"},
        {"userId": "userA", "productId": "p2", "eventType": "add_to_cart"},
    ]
    results = build_recommendations(events, CATALOG)

    assert "userA" not in results  # no purchases -> no entry at all


def test_top_n_limit_is_respected():
    events = [{"userId": "userA", "productId": "p1", "eventType": "purchase"}]
    results = build_recommendations(events, CATALOG, top_n=2)

    assert len(results.get("userA", [])) <= 2
