import asyncio
import sys
from pathlib import Path

# Add backend to path
sys.path.append(str(Path(__file__).parent))

from services.tmdb_client import get_tmdb_client

async def main():
    print("🧪 Testing Provider Synchronization...")
    client = get_tmdb_client()
    
    print("\n[1] Reading misplataformas.txt...")
    platform_file = Path(__file__).parent.parent / "misplataformas.txt"
    if platform_file.exists():
        print(f"   Found file at {platform_file}")
        print(f"   Content preview:")
        with open(platform_file, "r") as f:
            print(f.read()[:200] + "...")
    else:
        print(f"   ❌ File NOT found at {platform_file}")
        return

    print("\n[2] Running validation logic...")
    providers = await client.validate_provider_ids()
    
    print("\n[3] Final Active Providers:")
    for name, pid in providers.items():
        print(f"   • {name}: {pid}")
        
    await client.close_client()

if __name__ == "__main__":
    asyncio.run(main())
