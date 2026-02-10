import httpx
import json
import asyncio

async def test():
    async with httpx.AsyncClient() as client:
        # 1. List channels
        r = await client.get("http://localhost:8000/api/channels")
        print(f"List channels status: {r.status_code}")
        
        # 2. Create channel
        new_channel = {
            "name": "Cine Checoslovaco",
            "icon": "🎥",
            "day_of_week": 4,
            "slots": [
                {
                    "start": "00:00",
                    "end": "23:59",
                    "label": "Maratón Checo",
                    "content_type": "movie",
                    "original_language": "cs"
                }
            ]
        }
        r = await client.post("http://localhost:8000/api/channels", json=new_channel)
        print(f"Create channel response: {r.status_code} - {r.text}")
        
        # 3. Reload
        r = await client.post("http://localhost:8000/api/channels/reload")
        print(f"Reload response: {r.status_code}")

if __name__ == "__main__":
    asyncio.run(test())
