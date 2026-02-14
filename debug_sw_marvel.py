#!/usr/bin/env python3
"""Debug script to check why Star Wars/Marvel content isn't passing filters."""

import sys
import os
sys.path.insert(0, os.path.abspath('backend'))

import json
from services.content_metadata import ContentMetadata

# Load pool
pool_path = 'data/content_pool.json'
with open(pool_path, 'r') as f:
    pool_data = json.load(f)

# Load channels
channels_path = 'data/channel_templates.json'
with open(channels_path, 'r') as f:
    channels_data = json.load(f)

def test_channel(channel_id):
    channel = next((c for c in channels_data['channels'] if c.get('id') == channel_id), None)
    if not channel:
        print(f"❌ Channel {channel_id} not found!")
        return

    print(f"✅ Testing channel: {channel['name']} (ID: {channel_id})")
    
    # Found items for this channel (by title search)
    search_term = "star wars" if "star-wars" in channel_id else "marvel"
    if "marvel" in channel_id:
        search_term = "avenger" # Better for marvel
        
    items = [
        item for item in pool_data 
        if search_term.lower() in item.get('title', '').lower()
    ]
    print(f"📦 Found {len(items)} '{search_term}' items in pool\n")

    for slot_data in channel['slots']:
        print(f"📺 Slot: {slot_data.get('label', 'Untitled')}")
        
        # Build filter dict
        slot_filters = {"channel_id": channel_id}
        for key in ['content_type', 'genres', 'decade', 'vote_average_min', 'universes', 'keywords', 'exclude_keywords', 'title_contains']:
            if slot_data.get(key):
                slot_filters[key] = slot_data[key]
        
        eligible_count = 0
        for item_data in items[:15]: # Limit to 15 for output
            item = ContentMetadata.from_dict(item_data)
            matches = item.matches_slot_filters(slot_filters)
            
            status = "✅" if matches else "❌"
            reason = ""
            if not matches:
                # Check why
                if slot_filters.get('content_type') and item.media_type != slot_filters['content_type']:
                    reason = f"Type: {item.media_type} != {slot_filters['content_type']}"
                elif slot_filters.get('universes') and not set(slot_filters['universes']).intersection(set(item.universes)):
                    reason = f"Universe: {item.universes} vs {slot_filters['universes']}"
                elif slot_filters.get('title_contains'):
                    patterns = [p.lower() for p in slot_filters['title_contains']]
                    if not any(p in item.title.lower() or p in item.overview.lower() for p in patterns):
                        reason = f"Title Patterns: {slot_filters['title_contains']}"
                else:
                    reason = "Other filter"
            
            print(f"   {status} {item.title} ({item.media_type}) {f'- {reason}' if reason else ''}")
            if matches: eligible_count += 1
        
        print(f"   Total eligible (of sample): {eligible_count}/15\n")

print("--- SUPERMAN ---")
test_channel("superman")
print("\n--- STAR WARS ---")
test_channel("star-wars-universe")
print("\n--- MARVEL ---")
test_channel("marvel-universe")
