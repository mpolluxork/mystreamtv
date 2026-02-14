#!/usr/bin/env python3
"""Debug script to check why Superman content isn't passing filters."""

import sys
import os
sys.path.insert(0, os.path.abspath('backend'))

import json
from services.content_metadata import ContentMetadata

# Load pool
pool_path = 'data/content_pool.json'
if not os.path.exists(pool_path):
    print(f"❌ {pool_path} not found!")
    sys.exit(1)

with open(pool_path, 'r') as f:
    pool_data = json.load(f)

# Load channels
channels_path = 'data/channel_templates.json'
if not os.path.exists(channels_path):
    print(f"❌ {channels_path} not found!")
    sys.exit(1)

with open(channels_path, 'r') as f:
    channels_data = json.load(f)

# Find Superman channel
superman_channel = None
for channel in channels_data['channels']:
    if channel.get('id') == 'superman' or 'SUPERMAN' in channel.get('name', '').upper():
        superman_channel = channel
        break

if not superman_channel:
    print("❌ Superman channel not found!")
    sys.exit(1)

print(f"✅ Found channel: {superman_channel['name']} (ID: {superman_channel.get('id')})")
print(f"   Slots: {len(superman_channel['slots'])}\n")

# Find Superman items in pool (Searching in title OR overview)
# This mimics the user's grep but is slightly more focused
superman_items = [
    item for item in pool_data 
    if 'superman' in item.get('title', '').lower() or 
       'superman' in item.get('overview', '').lower()
]
print(f"📦 Found {len(superman_items)} Superman-related items in pool (by title/overview search)\n")

# Test each slot
for slot_data in superman_channel['slots']:
    print(f"📺 Slot: {slot_data['label']}")
    
    # Build filter dict - Exactly as ScheduleEngine._filter_pool_by_slot does
    slot_filters = {"channel_id": superman_channel.get('id')}
    
    if slot_data.get('content_type'):
        slot_filters['content_type'] = slot_data['content_type']
    if slot_data.get('genres'):
        slot_filters['genres'] = slot_data['genres']
    if slot_data.get('decade'):
        slot_filters['decade'] = slot_data['decade']
    if slot_data.get('vote_average_min'):
        slot_filters['vote_average_min'] = slot_data['vote_average_min']
    if slot_data.get('universes'):
        slot_filters['universes'] = slot_data['universes']
    if slot_data.get('keywords'):
        slot_filters['keywords'] = slot_data['keywords']
    if slot_data.get('exclude_keywords'):
        slot_filters['exclude_keywords'] = slot_data['exclude_keywords']
    if slot_data.get('title_contains'):
        slot_filters['title_contains'] = slot_data['title_contains']
    
    print(f"   Active Filters: {slot_filters}\n")
    
    # Test each Superman item
    eligible_count = 0
    matches_list = []
    
    for item_data in superman_items:
        # Create ContentMetadata object
        item = ContentMetadata.from_dict(item_data)
        
        # Test if it matches
        matches = item.matches_slot_filters(slot_filters)
        
        if matches:
            eligible_count += 1
            matches_list.append(f"   ✅ {item.title} ({item.media_type})")
        else:
            reason = "Unknown"
            # Quick check for WHY it failed
            if item.media_type != slot_filters.get('content_type'):
                reason = f"Type mismatch: {item.media_type} != {slot_filters.get('content_type')}"
            elif slot_filters.get('vote_average_min') and item.vote_average < slot_filters['vote_average_min']:
                reason = f"Rating too low: {item.vote_average} < {slot_filters['vote_average_min']}"
            elif slot_filters.get('universes'):
                if not set(slot_filters['universes']).intersection(set(item.universes)):
                    reason = f"Universe mismatch: {item.universes} does not contain any of {slot_filters['universes']}"
            
            matches_list.append(f"   ❌ {item.title} ({item.media_type}) - {reason}")
    
    # Show only first 15 results to avoid clutter, or all if less
    for m in matches_list[:15]:
        print(m)
    if len(matches_list) > 15:
        print(f"   ... and {len(matches_list) - 15} more")
        
    print(f"\n   Total eligible: {eligible_count}/{len(superman_items)}\n")
    print("="*60)
    print()
