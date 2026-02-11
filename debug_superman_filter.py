#!/usr/bin/env python3
"""Debug script to check why Superman content isn't passing filters."""

import sys
sys.path.insert(0, 'backend')

import json
from services.content_metadata import ContentMetadata

# Load pool
with open('data/content_pool.json', 'r') as f:
    pool_data = json.load(f)

# Load channels
with open('data/channel_templates.json', 'r') as f:
    channels_data = json.load(f)

# Find Superman channel
superman_channel = None
for channel in channels_data['channels']:
    if 'SUPERMAN' in channel['name']:
        superman_channel = channel
        break

if not superman_channel:
    print("❌ Superman channel not found!")
    sys.exit(1)

print(f"✅ Found channel: {superman_channel['name']}")
print(f"   Slots: {len(superman_channel['slots'])}\n")

# Find Superman items in pool
superman_items = [item for item in pool_data if 'superman' in item.get('title', '').lower()]
print(f"📦 Found {len(superman_items)} Superman items in pool\n")

# Test each slot
for slot_data in superman_channel['slots']:
    print(f"📺 Slot: {slot_data['label']}")
    print(f"   content_type: {slot_data.get('content_type')}")
    print(f"   genres: {slot_data.get('genres', [])}")
    print(f"   keywords: {slot_data.get('keywords', [])}")
    print(f"   vote_average_min: {slot_data.get('vote_average_min')}")
    print()
    
    # Build filter dict
    slot_filters = {}
    if slot_data.get('content_type'):
        slot_filters['content_type'] = slot_data['content_type']
    if slot_data.get('genres'):
        slot_filters['genres'] = slot_data['genres']
    if slot_data.get('keywords'):
        slot_filters['keywords'] = slot_data['keywords']
    if slot_data.get('vote_average_min'):
        slot_filters['vote_average_min'] = slot_data['vote_average_min']
    
    print(f"   Filters: {slot_filters}\n")
    
    # Test each Superman item
    eligible_count = 0
    for item_data in superman_items:
        # Create ContentMetadata object
        item = ContentMetadata(**item_data)
        
        # Test if it matches
        matches = item.matches_slot_filters(slot_filters)
        
        if matches:
            eligible_count += 1
            print(f"   ✅ {item.title} ({item.media_type})")
        else:
            print(f"   ❌ {item.title} ({item.media_type})")
            print(f"      Genres: {item.genres}")
            print(f"      Vote: {item.vote_average}")
    
    print(f"\n   Total eligible: {eligible_count}/{len(superman_items)}\n")
    print("="*60)
    print()
