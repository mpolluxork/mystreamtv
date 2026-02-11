"""
EPG Router for MyStreamTV.
Endpoints for channel listing, schedule, and now-playing.
"""
from datetime import datetime, date, timedelta
from typing import List, Optional
from fastapi import APIRouter, Query, HTTPException

from services.schedule_engine import ScheduleEngine, generate_deep_link
from services.tmdb_client import get_tmdb_client
from models.models import Channel, Program

router = APIRouter()

# Singleton schedule engine
_engine: Optional[ScheduleEngine] = None


def get_engine() -> ScheduleEngine:
    """Get or create schedule engine singleton."""
    global _engine
    if _engine is None:
        _engine = ScheduleEngine()
    return _engine


@router.get("/channels")
async def list_channels():
    """
    Get list of all available channels.
    Returns channel metadata without full schedule.
    """
    engine = get_engine()
    channels = engine.get_all_channels()
    
    return {
        "channels": [ch.to_dict() for ch in channels],
        "count": len(channels),
    }


@router.get("/guide")
async def get_guide(
    start: Optional[str] = Query(None, description="Start datetime ISO format"),
    end: Optional[str] = Query(None, description="End datetime ISO format"),
    hours: int = Query(6, description="Hours of guide to show from now"),
):
    """
    Get EPG guide for all channels within time range.
    Returns programs organized by channel.
    """
    engine = get_engine()
    now = datetime.now()
    
    # Parse time range
    if start:
        start_time = datetime.fromisoformat(start)
    else:
        start_time = now - timedelta(hours=1)  # Show 1 hour in the past
    
    if end:
        end_time = datetime.fromisoformat(end)
    else:
        end_time = now + timedelta(hours=hours)
    
    guide_data = []
    
    # Clear usage tracking for the target date to ensure fresh deduplication
    engine._clear_usage_for_date(start_time.date())
    if end_time.date() > start_time.date():
        engine._clear_usage_for_date(end_time.date())
    
    for channel in engine.get_all_channels():
        # Get today's and possibly tomorrow's schedule
        target_date = start_time.date()
        schedule = await engine.generate_schedule_for_date(channel, target_date)
        
        # If end time crosses midnight, also get next day
        if end_time.date() > target_date:
            next_schedule = await engine.generate_schedule_for_date(
                channel, 
                target_date + timedelta(days=1)
            )
            schedule = schedule + next_schedule
        
        # Filter to time range
        programs_in_range = engine.get_programs_in_range(
            schedule, start_time, end_time
        )
        
        # Find now playing
        now_playing = engine.get_now_playing(channel, schedule, now)
        
        guide_data.append({
            "channel": channel.to_dict(),
            "programs": [p.to_dict() for p in programs_in_range],
            "now_playing": now_playing.to_dict() if now_playing else None,
        })
    
    return {
        "start_time": start_time.isoformat(),
        "end_time": end_time.isoformat(),
        "current_time": now.isoformat(),
        "guide": guide_data,
    }


@router.get("/now-playing")
async def get_all_now_playing():
    """
    Get what's currently playing on all channels.
    Quick overview for the EPG grid.
    """
    engine = get_engine()
    now = datetime.now()
    today = now.date()
    
    now_playing_list = []
    
    for channel in engine.get_all_channels():
        schedule = await engine.generate_schedule_for_date(channel, today)
        now_playing = engine.get_now_playing(channel, schedule, now)
        
        if now_playing:
            now_playing_list.append({
                "channel": {
                    "id": channel.id,
                    "name": channel.name,
                    "icon": channel.icon,
                },
                "program": now_playing.to_dict(),
            })
    
    return {
        "current_time": now.isoformat(),
        "now_playing": now_playing_list,
    }


@router.get("/channel/{channel_id}/schedule")
async def get_channel_schedule(
    channel_id: str,
    target_date: Optional[str] = Query(None, description="Date in YYYY-MM-DD format"),
):
    """
    Get full day schedule for a specific channel.
    """
    engine = get_engine()
    
    # Find channel
    channel = None
    for ch in engine.get_all_channels():
        if ch.id == channel_id:
            channel = ch
            break
    
    if not channel:
        raise HTTPException(status_code=404, detail=f"Channel {channel_id} not found")
    
    # Parse date
    if target_date:
        schedule_date = date.fromisoformat(target_date)
    else:
        schedule_date = date.today()
    
    schedule = await engine.generate_schedule_for_date(channel, schedule_date)
    now_playing = engine.get_now_playing(channel, schedule, datetime.now())
    
    return {
        "channel": channel.to_dict(),
        "date": schedule_date.isoformat(),
        "programs": [p.to_dict() for p in schedule],
        "now_playing": now_playing.to_dict() if now_playing else None,
    }


@router.get("/program/{tmdb_id}/providers")
async def get_program_providers(tmdb_id: int, content_type: str = "movie"):
    """
    Get streaming providers and deep links for a specific program.
    Only returns providers from the user's platform list.
    """
    tmdb = get_tmdb_client()
    
    providers = await tmdb.get_watch_providers(tmdb_id, content_type)
    
    # Get user's provider IDs
    user_provider_ids = set(tmdb.providers.values())
    
    # Collect providers from all "watchable" categories (no buy/rent)
    flatrate = providers.get("flatrate", [])
    free = providers.get("free", [])
    ads = providers.get("ads", [])
    
    # Merge and deduplicate, filtering to only user's platforms
    all_watch_providers = []
    seen_ids = set()
    
    for category in [flatrate, free, ads]:
        for p in category:
            provider_id = p.get("provider_id")
            # CRITICAL: Only include if provider is in user's list
            if provider_id and provider_id in user_provider_ids and provider_id not in seen_ids:
                all_watch_providers.append(p)
                seen_ids.add(provider_id)
                
    links = []
    for provider in all_watch_providers:
        provider_name = provider["provider_name"]
        deep_link = generate_deep_link(provider_name, tmdb_id)
        
        links.append({
            "provider_name": provider_name,
            "logo_path": provider.get("logo_path"),
            "deep_link": deep_link,
        })
    
    return {
        "tmdb_id": tmdb_id,
        "content_type": content_type,
        "providers": links,
        "tmdb_link": providers.get("link"),
    }
