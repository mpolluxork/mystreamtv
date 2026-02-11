#!/usr/bin/env python3
"""
Migration script to remove day_of_week from channel_templates.json
"""
import json
from pathlib import Path

def migrate_channel_templates():
    """Remove day_of_week field from all channels."""
    template_path = Path(__file__).parent.parent.parent / "data" / "channel_templates.json"
    
    if not template_path.exists():
        print(f"❌ File not found: {template_path}")
        return
    
    # Backup original
    backup_path = template_path.with_suffix('.json.backup')
    with open(template_path, 'r', encoding='utf-8') as f:
        original_data = f.read()
    
    with open(backup_path, 'w', encoding='utf-8') as f:
        f.write(original_data)
    
    print(f"✅ Backup created: {backup_path}")
    
    # Load and modify
    data = json.loads(original_data)
    
    removed_count = 0
    for channel in data.get("channels", []):
        if "day_of_week" in channel:
            del channel["day_of_week"]
            removed_count += 1
    
    # Save modified
    with open(template_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    
    print(f"✅ Removed day_of_week from {removed_count} channels")
    print(f"✅ Updated: {template_path}")

if __name__ == "__main__":
    migrate_channel_templates()
