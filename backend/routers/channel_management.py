from fastapi import APIRouter, HTTPException, Depends, BackgroundTasks
from typing import List, Dict, Any, Optional
from pathlib import Path
import json
from datetime import datetime

from services.schedule_engine import ScheduleEngine
from models.models import Channel, TimeSlot, ContentType

router = APIRouter(prefix="/api/channels", tags=["Channel Management"])

# Helper to get the absolute path to templates
TEMPLATES_PATH = Path(__file__).parent.parent.parent / "data" / "channel_templates.json"
BLUEPRINT_PATH = Path(__file__).parent.parent.parent / "data" / "channel_slots_blueprint.json"

def get_engine():
    # In a real app, this would be a dependency injected singleton
    from main import engine
    return engine

@router.get("", response_model=List[Dict[str, Any]])
async def list_channels(include_disabled: bool = True, engine: ScheduleEngine = Depends(get_engine)):
    """List all channels from memory (synced with JSON)."""
    return [c.to_dict() for c in engine.get_all_channels(include_disabled=include_disabled)]

@router.post("")
async def create_channel(channel_data: Dict[str, Any], background_tasks: BackgroundTasks, engine: ScheduleEngine = Depends(get_engine)):
    """Create a new channel and save to JSON."""
    try:
        with open(TEMPLATES_PATH, "r", encoding="utf-8") as f:
            data = json.load(f)
        
        # Simple ID generation if not provided
        if "id" not in channel_data:
            channel_data["id"] = channel_data["name"].lower().replace(" ", "-")
        
        # Check for duplicates
        if any(c["id"] == channel_data["id"] for c in data["channels"]):
            raise HTTPException(status_code=400, detail="Channel ID already exists")
            
        data["channels"].append(channel_data)
        
        with open(TEMPLATES_PATH, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=4, ensure_ascii=False)
            
        # Reload channels and expand pool only for this new channel
        engine.reload_channels()
        background_tasks.add_task(engine.expand_pool_for_channel, channel_data["id"])
        
        return {"status": "success", "channel_id": channel_data["id"]}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.put("/{channel_id}")
async def update_channel(channel_id: str, channel_data: Dict[str, Any], background_tasks: BackgroundTasks, engine: ScheduleEngine = Depends(get_engine)):
    """Update an existing channel."""
    try:
        with open(TEMPLATES_PATH, "r", encoding="utf-8") as f:
            data = json.load(f)
            
        found = False
        for i, c in enumerate(data["channels"]):
            if c["id"] == channel_id:
                data["channels"][i] = channel_data
                found = True
                break
                
        if not found:
            raise HTTPException(status_code=404, detail="Channel not found")
            
        with open(TEMPLATES_PATH, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=4, ensure_ascii=False)
            
        # Reload channels and expand pool only for this updated channel
        engine.reload_channels()
        background_tasks.add_task(engine.expand_pool_for_channel, channel_id)
        return {"status": "success"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.delete("/{channel_id}")
async def delete_channel(channel_id: str, background_tasks: BackgroundTasks, engine: ScheduleEngine = Depends(get_engine)):
    """Delete a channel."""
    try:
        with open(TEMPLATES_PATH, "r", encoding="utf-8") as f:
            data = json.load(f)
            
        data["channels"] = [c for c in data["channels"] if c["id"] != channel_id]
        
        with open(TEMPLATES_PATH, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=4, ensure_ascii=False)
            
        background_tasks.add_task(engine.reload_channels)
        return {"status": "success"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/reload")
async def reload_all(background_tasks: BackgroundTasks, engine: ScheduleEngine = Depends(get_engine)):
    """Force a reload and discovery for all channels."""
    background_tasks.add_task(engine.reload_and_discover)
    return {"status": "reload-started"}

@router.get("/blueprint")
async def get_blueprint():
    """Get the default channel blueprint for creating new channels."""
    try:
        if not BLUEPRINT_PATH.exists():
            return {"channels": []}
        with open(BLUEPRINT_PATH, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/tmdb/genres")
async def get_genres(engine: ScheduleEngine = Depends(get_engine)):
    """Proxy to get genres from TMDB client."""
    # Assuming tmdb_client has a method for this or we return a static list
    # For now, return a common list or fetch from engine.tmdb
    return [
        {"id": 28, "name": "Action"},
        {"id": 12, "name": "Adventure"},
        {"id": 16, "name": "Animation"},
        {"id": 35, "name": "Comedy"},
        {"id": 80, "name": "Crime"},
        {"id": 18, "name": "Drama"},
        {"id": 10751, "name": "Family"},
        {"id": 14, "name": "Fantasy"},
        {"id": 36, "name": "History"},
        {"id": 27, "name": "Horror"},
        {"id": 10402, "name": "Music"},
        {"id": 9648, "name": "Mystery"},
        {"id": 10749, "name": "Romance"},
        {"id": 878, "name": "Science Fiction"},
        {"id": 53, "name": "Thriller"},
        {"id": 10759, "name": "Action & Adventure (TV)"},
        {"id": 10765, "name": "Sci-Fi & Fantasy (TV)"}
    ]
