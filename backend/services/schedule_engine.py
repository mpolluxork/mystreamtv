"""
Schedule Engine for MyStreamTV.
Refactored to use global content pool for multi-channel content discovery.
"""
import json
import hashlib
import random
from datetime import datetime, date, time, timedelta
from pathlib import Path
from typing import List, Dict, Optional, Any

import sys
sys.path.append(str(Path(__file__).parent.parent))

from models.models import Channel, TimeSlot, Program, ContentType
from services.tmdb_client import TMDBClient, get_tmdb_client
from services.content_metadata import ContentMetadata
from services.content_pool_builder import build_content_pool


class ScheduleEngine:
    """
    Generates and manages the EPG schedule using a global content pool.
    Content can appear in multiple channels based on multi-dimensional matching.
    """
    
    def __init__(self, tmdb_client: Optional[TMDBClient] = None):
        self.tmdb = tmdb_client or get_tmdb_client()
        self.channels: List[Channel] = []
        self._global_pool: List[ContentMetadata] = []
        self._schedule_cache: Dict[str, List[Program]] = {}
        
        # Load channel templates and existing pool
        self._load_channel_templates()
        self._load_content_pool()
    
    def _load_content_pool(self):
        """Load persisted content pool from JSON."""
        pool_path = Path(__file__).parent.parent.parent / "data" / "content_pool.json"
        if not pool_path.exists():
            return
            
        try:
            with open(pool_path, "r", encoding="utf-8") as f:
                data = json.load(f)
                self._global_pool = [ContentMetadata.from_dict(item) for item in data]
            print(f"📦 Loaded {len(self._global_pool)} items from persistent pool.")
        except Exception as e:
            print(f"⚠️ Error loading content pool: {e}")

    def _save_content_pool(self):
        """Save current pool to JSON."""
        pool_path = Path(__file__).parent.parent.parent / "data" / "content_pool.json"
        pool_path.parent.mkdir(parents=True, exist_ok=True)
        try:
            with open(pool_path, "w", encoding="utf-8") as f:
                json.dump([m.to_dict() for m in self._global_pool], f, indent=2, ensure_ascii=False)
        except Exception as e:
            print(f"⚠️ Error saving content pool: {e}")

    def reload_channels(self):
        """Reload channels from JSON and clear cache."""
        self.channels = []
        self._load_channel_templates()
        self._schedule_cache = {}
        print("🔄 Channels reloaded.")

    async def reload_and_discover(self):
        """Reload channels and trigger targeted discovery for new criteria."""
        self.reload_channels()
        await self.expand_pool_for_all_channels()
        self._save_content_pool()

    async def expand_pool_for_all_channels(self):
        """Analyze all channels and discover content for their specific filters."""
        from services.content_pool_builder import discover_content_for_filters
        
        print("🔍 Expanding content pool based on channel filters...")
        seen_ids = {(m.tmdb_id, m.media_type) for m in self._global_pool}
        new_items_count = 0
        
        for channel in self.channels:
            if not channel.enabled:
                continue
            for slot in channel.slots:
                # Convert slot to filter dict for discovery
                filters = {
                    "genres": slot.genre_ids,
                    "decade": slot.decade,
                    "content_type": slot.content_type.value,
                    "original_language": slot.original_language,
                    "production_countries": slot.production_countries,
                    "vote_average_min": slot.vote_average_min,
                    "with_people": slot.with_people,
                    "keywords": slot.keywords,
                    "universes": slot.universes
                }
                
                # Perform discovery
                results = await discover_content_for_filters(self.tmdb, filters)
                for metadata in results:
                    cid = (metadata.tmdb_id, metadata.media_type)
                    if cid not in seen_ids:
                        self._global_pool.append(metadata)
                        seen_ids.add(cid)
                        new_items_count += 1
                        
        print(f"✅ Pool expansion complete. Added {new_items_count} new items.")
        if new_items_count > 0:
            self._save_content_pool()
    
    def _load_channel_templates(self):
        """Load channel definitions from JSON template."""
        template_path = Path(__file__).parent.parent.parent / "data" / "channel_templates.json"
        
        if not template_path.exists():
            print(f"Warning: Channel templates not found at {template_path}")
            return
        
        with open(template_path, "r", encoding="utf-8") as f:
            data = json.load(f)
        
        for ch_data in data.get("channels", []):
            slots = []
            for slot_data in ch_data.get("slots", []):
                # Robust timing parsing
                start_str = slot_data.get("start", "00:00")
                end_str = slot_data.get("end", "04:00")
                try:
                    start_parts = start_str.split(":")
                    start_time = time(int(start_parts[0]), int(start_parts[1]))
                except (ValueError, IndexError):
                    start_time = time(0, 0)
                
                try:
                    end_parts = end_str.split(":")
                    end_time = time(int(end_parts[0]), int(end_parts[1]))
                except (ValueError, IndexError):
                    end_time = time(4, 0)

                # Robust content type parsing
                ctype_str = slot_data.get("content_type", "movie")
                try:
                    content_type = ContentType(ctype_str)
                except ValueError:
                    content_type = ContentType.MOVIE

                decade = None
                if slot_data.get("decade"):
                    decade = tuple(slot_data["decade"])
                
                slot = TimeSlot(
                    start_time=start_time,
                    end_time=end_time,
                    label=slot_data.get("label", "Untitled Slot"),
                    genre_ids=slot_data.get("genres", []),
                    decade=decade,
                    keywords=slot_data.get("keywords", []),
                    filter_type=slot_data.get("filter_type"),
                    content_type=content_type,
                    collections=slot_data.get("collections", []),
                    original_language=slot_data.get("original_language"),
                    production_countries=slot_data.get("production_countries"),
                    vote_average_min=slot_data.get("vote_average_min"),
                    with_people=slot_data.get("with_people", []),
                    universes=slot_data.get("universes", []),
                    exclude_keywords=slot_data.get("exclude_keywords", []),
                )
                slots.append(slot)
            
            channel = Channel(
                id=ch_data["id"],
                name=ch_data["name"],
                icon=ch_data.get("icon", "📺"),
                day_of_week=ch_data["day_of_week"],
                enabled=ch_data.get("enabled", True),
                priority=ch_data.get("priority", 50),
                description=ch_data.get("description"),
                slots=slots,
            )
            self.channels.append(channel)
    
    async def build_global_pool(self, max_items: int = 1000):
        """Build the global content pool once at startup. Merges with existing items."""
        print(f"🔨 Building global content pool (current size: {len(self._global_pool)})...")
        new_items = await build_content_pool(
            self.tmdb,
            max_items=max_items
        )
        
        # Merge new items without duplicates
        seen_ids = {item.tmdb_id for item in self._global_pool}
        added_count = 0
        for item in new_items:
            if item.tmdb_id not in seen_ids:
                self._global_pool.append(item)
                seen_ids.add(item.tmdb_id)
                added_count += 1
        
        print(f"✅ Global pool ready with {len(self._global_pool)} items (added {added_count} new items)")
        self._save_content_pool()
    
    def _get_seed(self, channel_id: str, target_date: date, slot_index: int) -> int:
        """Generate deterministic seed from channel, date, and slot."""
        seed_string = f"{channel_id}:{target_date.isoformat()}:{slot_index}"
        hash_bytes = hashlib.md5(seed_string.encode()).digest()
        return int.from_bytes(hash_bytes[:4], byteorder='big')
    
    def _filter_pool_by_slot(
        self,
        pool: List[ContentMetadata],
        slot: TimeSlot
    ) -> List[ContentMetadata]:
        """
        Filter the global pool to get content eligible for a specific slot.
        Uses ContentMetadata.matches_slot_filters() for multi-dimensional matching.
        """
        # Build filter dictionary from slot
        slot_filters = {}
        
        # Only filter by content type if explicitly set (to avoid default MOVIE filter on custom slots)
        if slot.content_type:
            slot_filters["content_type"] = slot.content_type.value
        
        if slot.genre_ids:
            slot_filters["genres"] = slot.genre_ids
        
        if slot.decade:
            slot_filters["decade"] = slot.decade
        
        if slot.vote_average_min:
            slot_filters["vote_average_min"] = slot.vote_average_min
        
        if slot.universes:
            slot_filters["universes"] = slot.universes
        
        if slot.keywords:
            slot_filters["keywords"] = slot.keywords
        
        if slot.exclude_keywords:
            slot_filters["exclude_keywords"] = slot.exclude_keywords
        
        if slot.original_language:
            slot_filters["original_language"] = slot.original_language
        
        if slot.production_countries:
            slot_filters["production_countries"] = slot.production_countries
        
        if slot.with_people:
            slot_filters["with_people"] = slot.with_people
        
        # Filter pool
        eligible = [
            content for content in pool
            if content.matches_slot_filters(slot_filters)
        ]
        
        return eligible
    
    def _fill_slot_with_content(
        self,
        slot: TimeSlot,
        eligible_content: List[ContentMetadata],
        slot_start: datetime,
        slot_end: datetime,
        seed: int
    ) -> List[Program]:
        """
        Fill a time slot with programs from eligible content.
        Uses deterministic shuffling based on seed.
        """
        programs = []
        current_time = slot_start
        
        # Seed random for deterministic selection
        rng = random.Random(seed)
        
        # Shuffle eligible content deterministically
        shuffled = eligible_content.copy()
        rng.shuffle(shuffled)
        
        content_index = 0
        
        while current_time < slot_end and content_index < len(shuffled):
            content = shuffled[content_index]
            content_index += 1
            
            # Get runtime (use default if not available)
            runtime = content.runtime
            if runtime is None:
                runtime = 45 if content.media_type == "tv" else 90
            
            # Calculate program end time
            program_end = current_time + timedelta(minutes=runtime)
            
            # Skip if would overflow slot too much (allow 15 min tolerance)
            if program_end > slot_end + timedelta(minutes=15):
                continue
            
            # Create program
            program_id = f"{content.tmdb_id}_{current_time.isoformat()}"
            
            # Get provider info (use first available)
            provider_name = None
            provider_logo = None
            deep_link = None
            if content.providers:
                first_provider = content.providers[0]
                provider_name = first_provider.get("provider_name")
                provider_logo = first_provider.get("logo_path")
                deep_link = generate_deep_link(provider_name, content.tmdb_id)
            
            program = Program(
                id=program_id,
                tmdb_id=content.tmdb_id,
                content_type=ContentType(content.media_type),
                title=content.title,
                original_title=content.original_title,
                overview=content.overview,
                runtime_minutes=runtime,
                start_time=current_time,
                end_time=program_end,
                poster_path=content.poster_path,
                backdrop_path=content.backdrop_path,
                genres=content.genres,
                release_year=content.year,
                vote_average=content.vote_average,
                slot_label=slot.label, # Populate slot label
                provider_name=provider_name,
                provider_logo=provider_logo,
                deep_link=deep_link,
            )
            
            programs.append(program)
            current_time = program_end
        
        return programs
    
    async def generate_schedule_for_date(
        self,
        channel: Channel,
        target_date: date,
    ) -> List[Program]:
        """
        Generate full day schedule for a channel using the global pool.
        """
        # Build pool if not already built
        if not self._global_pool:
            await self.build_global_pool()
        
        cache_key = f"{channel.id}:{target_date.isoformat()}"
        
        if cache_key in self._schedule_cache:
            return self._schedule_cache[cache_key]
        
        all_programs = []
        
        for slot_index, slot in enumerate(channel.slots):
            seed = self._get_seed(channel.id, target_date, slot_index)
            
            # Calculate slot datetime
            slot_start = datetime.combine(target_date, slot.start_time)
            slot_end = datetime.combine(target_date, slot.end_time)
            
            # Handle midnight crossing
            if slot.end_time <= slot.start_time:
                slot_end += timedelta(days=1)
            
            # Filter pool for this slot
            eligible_content = self._filter_pool_by_slot(self._global_pool, slot)
            
            if not eligible_content:
                print(f"⚠️ No eligible content for {channel.name} - {slot.label}")
                continue
            
            # Fill slot with programs
            programs = self._fill_slot_with_content(
                slot=slot,
                eligible_content=eligible_content,
                slot_start=slot_start,
                slot_end=slot_end,
                seed=seed
            )
            
            all_programs.extend(programs)
        
        # Sort by start time
        all_programs.sort(key=lambda p: p.start_time)
        
        # Cache
        self._schedule_cache[cache_key] = all_programs
        
        return all_programs
    
    def get_now_playing(
        self,
        channel: Channel,
        schedule: List[Program],
        current_time: Optional[datetime] = None,
    ) -> Optional[Program]:
        """Find what's currently playing on a channel."""
        if current_time is None:
            current_time = datetime.now()
        
        for program in schedule:
            if program.start_time <= current_time < program.end_time:
                return program
        
        return None
    
    def get_programs_in_range(
        self,
        schedule: List[Program],
        start_time: datetime,
        end_time: datetime,
    ) -> List[Program]:
        """Get programs that overlap with the given time range."""
        return [
            p for p in schedule
            if p.end_time > start_time and p.start_time < end_time
        ]
    
    def get_channel_by_day(self, day_of_week: int) -> Optional[Channel]:
        """Get the channel for a specific day of week."""
        for channel in self.channels:
            if channel.day_of_week == day_of_week:
                return channel
        return None
    
    def get_all_channels(self, include_disabled: bool = False) -> List[Channel]:
        """Get all configured channels, optionally including disabled ones."""
        if include_disabled:
            return sorted(self.channels, key=lambda x: x.priority, reverse=True)
        return sorted([c for c in self.channels if c.enabled], key=lambda x: x.priority, reverse=True)


# Deep link URL generators
DEEP_LINK_TEMPLATES = {
    "netflix": "https://www.netflix.com/title/{id}",
    "disney": "https://www.disneyplus.com/video/{id}",
    "hbo_max": "https://play.max.com/movie/{id}",
    "prime": "https://www.primevideo.com/detail/{id}",
}


def generate_deep_link(provider_name: str, content_id: int) -> Optional[str]:
    """Generate deep link URL for a streaming provider."""
    if not provider_name:
        return None
    
    provider_key = provider_name.lower().replace(" ", "_").replace("+", "")
    
    if "netflix" in provider_key:
        return DEEP_LINK_TEMPLATES["netflix"].format(id=content_id)
    elif "disney" in provider_key:
        return DEEP_LINK_TEMPLATES["disney"].format(id=content_id)
    elif "max" in provider_key or "hbo" in provider_key:
        return DEEP_LINK_TEMPLATES["hbo_max"].format(id=content_id)
    elif "prime" in provider_key or "amazon" in provider_key:
        return DEEP_LINK_TEMPLATES["prime"].format(id=content_id)
    
    return None
