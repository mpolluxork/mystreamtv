#!/usr/bin/env python3
"""Test the new title_contains filter."""

import sys
sys.path.insert(0, 'backend')

import json
from services.content_metadata import ContentMetadata

# Load pool
with open('data/content_pool.json', 'r') as f:
    pool_data = json.load(f)

print(f"📦 Pool has {len(pool_data)} items\n")

# Test title_contains filter
slot_filters = {
    "content_type": "movie",
    "vote_average_min": 6.0,
    "title_contains": ["Superman", "Supergirl", "Man of Steel"]
}

print("🔍 Testing filter:")
print(f"   {slot_filters}\n")

eligible = []
for item_data in pool_data:
    item = ContentMetadata(**item_data)
    if item.matches_slot_filters(slot_filters):
        eligible.append(item)

print(f"✅ Found {len(eligible)} eligible movies\n")

# Show first 10
for item in eligible[:10]:
    print(f"  - {item.title} ({item.year}) - {item.vote_average}/10")

print(f"\n... and {len(eligible) - 10} more" if len(eligible) > 10 else "")
