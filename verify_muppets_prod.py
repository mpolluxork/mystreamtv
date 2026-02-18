import asyncio
import os
import sys

# Add backend to path
backend_path = os.getcwd() # Run from backend folder
sys.path.append(backend_path)
sys.path.append(os.path.join(backend_path, "services"))

async def verify_muppets():
    try:
        from services.schedule_engine import ScheduleEngine
    except ImportError as e:
        print(f"❌ Critical Error: {e}")
        print("Try running from inside the 'backend' folder or check dependencies.")
        return

    print("🚀 Starting Muppets discovery verification...")
    engine = ScheduleEngine()
    
    # Trigger expansion for the Muppets channel
    print("🔍 Searching for Muppets series (this may take a minute)...")
    await engine.expand_pool_for_channel("the-muppets")
    
    print("\n📝 Checking pool for Muppets results...")
    muppet_items = [m for m in engine._global_pool if "muppet" in m.title.lower() or "muppet" in m.original_title.lower()]
    
    for item in muppet_items:
        print(f"✅ Found: {item.title} ({item.year}) - ID: {item.tmdb_id}")
    
    success_ids = [1198, 105658, 63238, 192837] # Muppet Show, Muppets Now, Muppets Mayhem, Muppets
    found_success = [item for item in muppet_items if item.tmdb_id in success_ids]
    
    if found_success:
        print(f"\n✨ SUCCESS: {len(found_success)} Muppet series found!")
        for item in found_success:
             print(f"   - {item.title}")
    else:
        print("\n❌ FAILED: Known Muppet series still missing.")

if __name__ == "__main__":
    asyncio.run(verify_muppets())
