
import asyncio
import httpx
from typing import List, Dict, Any

async def diagnose_pool():
    print("🔍 Diagnostic: Checking MyStreamTV Content Pool...")
    
    async with httpx.AsyncClient(timeout=30.0) as client:
        # Check channels first
        try:
            resp = await client.get("http://localhost:8000/api/epg/channels")
            channels = resp.json()
            print(f"✅ Found {len(channels)} channels.")
        except Exception as e:
            print(f"❌ Error fetching channels: {e}")
            return

        # Check guide for Época de Oro
        try:
            resp = await client.get("http://localhost:8000/api/epg/guide?hours=4")
            guide = resp.json()
            
            epoca_channel = next((c for c in guide if c["id"] == "epoca-oro"), None)
            if epoca_channel:
                programs = epoca_channel.get("programs", [])
                print(f"📺 Época de Oro Channel: Found {len(programs)} programs.")
                for p in programs:
                    print(f"  - {p['title']} ({p.get('start_time')} - {p.get('end_time')})")
            else:
                print("❌ Época de Oro channel not found in guide.")
        except Exception as e:
            print(f"❌ Error fetching guide: {e}")

        # Check raw provider data for a few movies
        print("\n🧪 Testing provider availability for common Mexican titles...")
        # Search for "Pedro Infante" movies directly to see if they'd be eligible
        # (This is just to see if our system COULD find them)
        
if __name__ == "__main__":
    asyncio.run(diagnose_pool())
