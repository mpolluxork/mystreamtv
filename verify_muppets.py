import asyncio
import os
import sys

# Add backend to path
sys.path.append(os.path.join(os.getcwd(), "backend"))

from services.schedule_engine import ScheduleEngine
from services.tmdb_client import get_tmdb_client

async def verify_muppets():
    print("🚀 Starting Muppets discovery verification...")
    engine = ScheduleEngine()
    
    # We only want to trigger expansion for the Muppets channel
    # It has id 'the-muppets' according to channel_templates.json
    await engine.expand_pool_for_channel("the-muppets")
    
    print("\n📝 Checking pool for Muppets results...")
    muppet_items = [m for m in engine._global_pool if "muppet" in m.title.lower() or "muppet" in m.original_title.lower()]
    
    for item in muppet_items:
        print(f"✅ Found: {item.title} ({item.year}) - ID: {item.tmdb_id}")
    
    if any(item.tmdb_id == 1198 for item in muppet_items):
        print("\n✨ SUCCESS: 'The Muppet Show' (1198) was found!")
    else:
        print("\n❌ FAILED: 'The Muppet Show' (1198) still missing.")

if __name__ == "__main__":
    asyncio.run(verify_muppets())
