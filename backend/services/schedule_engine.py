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
        
        # Track content usage to prevent repetition across channels
        self._content_usage: Dict[str, set[int]] = {}  # {date_hour: {tmdb_ids}}
        
        # Track recently played content for cooldown (7 days for movies)
        self._recently_played: Dict[str, Dict[int, date]] = {}  # {channel_id: {tmdb_id: last_date}}
        
        # Load channel templates and existing pool
        self._load_channel_templates()
        self._load_content_pool()
        self._load_cooldown_data()
    
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

    async def build_global_pool(self, max_items: int = 1000):
        """Build the global content pool from TMDB."""
        print(f"🔨 Building global content pool (current size: {len(self._global_pool)})...")
        
        initial_size = len(self._global_pool)
        pool = await build_content_pool(self.tmdb, max_items=max_items)
        
        # Merge with existing pool (avoid duplicates)
        seen_ids = {(m.tmdb_id, m.media_type) for m in self._global_pool}
        new_items = 0
        
        for item in pool:
            cid = (item.tmdb_id, item.media_type)
            if cid not in seen_ids:
                self._global_pool.append(item)
                seen_ids.add(cid)
                new_items += 1
        
        print(f"✅ Global pool ready with {len(self._global_pool)} items (added {new_items} new items)")
        self._save_content_pool()
    
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
        print("🔄 Reloading channels and discovering content...")
        self.reload_channels()
        await self.expand_pool_for_all_channels()
        self._save_content_pool()
        print("✅ Reload complete")

    async def expand_pool_for_all_channels(self):
        """Analyze all channels and discover content for their specific filters."""
        from services.content_pool_builder import discover_content_for_filters
        
        print(f"🔍 Expanding content pool for {len(self.channels)} channels...")
        seen_ids = {(m.tmdb_id, m.media_type) for m in self._global_pool}
        new_items_count = 0
        
        for idx, channel in enumerate(self.channels, 1):
            if not channel.enabled:
                print(f"  ⏭️  [{idx}/{len(self.channels)}] Skipping disabled channel: {channel.name}")
                continue
            
            print(f"  🔍 [{idx}/{len(self.channels)}] Processing: {channel.name} ({len(channel.slots)} slots)")
            
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
                results = await discover_content_for_filters(self.tmdb, filters, max_results=50, origin_channel_id=channel.id)
                for metadata in results:
                    cid = (metadata.tmdb_id, metadata.media_type)
                    # Find if it already exists to merge attribution
                    existing = next((m for m in self._global_pool if (m.tmdb_id, m.media_type) == cid), None)
                    if existing:
                        if channel.id not in existing.origin_channels:
                            existing.origin_channels.append(channel.id)
                    elif cid not in seen_ids:
                        self._global_pool.append(metadata)
                        seen_ids.add(cid)
                        new_items_count += 1
                        
        print(f"✅ Pool expansion complete. Added {new_items_count} new items.")
        if new_items_count > 0:
            self._save_content_pool()
    
    async def expand_pool_for_channel(self, channel_id: str):
        """
        Expand pool only for a specific channel's filters.
        This is more efficient than reload_and_discover when only one channel changes.
        """
        from services.content_pool_builder import discover_content_for_filters
        
        # Find the channel
        channel = next((c for c in self.channels if c.id == channel_id), None)
        if not channel:
            print(f"⚠️ Channel {channel_id} not found")
            return
        
        print(f"🔍 Expanding pool for channel: {channel.name}")
        seen_ids = {(m.tmdb_id, m.media_type) for m in self._global_pool}
        new_items_count = 0
        
        for slot in channel.slots:
            # Convert slot to filter dict for discovery
            filters = {
                "genres": slot.genre_ids,
                "decade": slot.decade,
                "content_type": slot.content_type.value if slot.content_type else None,
                "original_language": slot.original_language,
                "production_countries": slot.production_countries,
                "vote_average_min": slot.vote_average_min,
                "with_people": slot.with_people,
                "keywords": slot.keywords,
                "universes": slot.universes
            }
            
            # Perform discovery with smaller batch size for single channel
            results = await discover_content_for_filters(self.tmdb, filters, max_results=30, origin_channel_id=channel_id)
            for metadata in results:
                cid = (metadata.tmdb_id, metadata.media_type)
                # Find if it already exists to merge attribution
                existing = next((m for m in self._global_pool if (m.tmdb_id, m.media_type) == cid), None)
                if existing:
                    if channel_id not in existing.origin_channels:
                        existing.origin_channels.append(channel_id)
                elif cid not in seen_ids:
                    self._global_pool.append(metadata)
                    seen_ids.add(cid)
                    new_items_count += 1
        
        print(f"✅ Added {new_items_count} items for channel {channel_id}")
        if new_items_count > 0:
            self._save_content_pool()

    
    def _mark_content_used(self, target_date: date, hour: int, tmdb_id: int):
        """Mark content as used for a specific date and hour."""
        key = f"{target_date.isoformat()}_{hour:02d}"
        if key not in self._content_usage:
            self._content_usage[key] = set()
        self._content_usage[key].add(tmdb_id)
    
    def _is_content_used(self, target_date: date, hour: int, tmdb_id: int) -> bool:
        """Check if content is already used in this time slot."""
        key = f"{target_date.isoformat()}_{hour:02d}"
        return tmdb_id in self._content_usage.get(key, set())
    
    def _clear_usage_for_date(self, target_date: date):
        """Clear usage tracking for a specific date (for regeneration)."""
        date_str = target_date.isoformat()
        keys_to_remove = [k for k in self._content_usage.keys() if k.startswith(date_str)]
        for key in keys_to_remove:
            del self._content_usage[key]

    def _load_cooldown_data(self):
        """Load cooldown tracking from JSON."""
        cooldown_path = Path(__file__).parent.parent.parent / "data" / "cooldown.json"
        if not cooldown_path.exists():
            return
        
        try:
            with open(cooldown_path, "r", encoding="utf-8") as f:
                data = json.load(f)
                # Convert date strings back to date objects
                for channel_id, items in data.items():
                    self._recently_played[channel_id] = {
                        int(tmdb_id): date.fromisoformat(date_str)
                        for tmdb_id, date_str in items.items()
                    }
            print(f"✅ Loaded cooldown data for {len(self._recently_played)} channels")
        except Exception as e:
            print(f"⚠️ Error loading cooldown data: {e}")
    
    def _save_cooldown_data(self):
        """Save cooldown tracking to JSON."""
        cooldown_path = Path(__file__).parent.parent.parent / "data" / "cooldown.json"
        try:
            # Convert date objects to strings
            data = {
                channel_id: {
                    str(tmdb_id): date_obj.isoformat()
                    for tmdb_id, date_obj in items.items()
                }
                for channel_id, items in self._recently_played.items()
            }
            with open(cooldown_path, "w", encoding="utf-8") as f:
                json.dump(data, f, indent=2, ensure_ascii=False)
        except Exception as e:
            print(f"⚠️ Error saving cooldown data: {e}")
    
    def _is_in_cooldown(self, channel_id: str, tmdb_id: int, media_type: str, current_date: date) -> bool:
        """Check if content is in cooldown period."""
        # TV shows NO tienen cooldown (tienen replay value)
        if media_type == "tv":
            return False
        
        # Películas tienen 7 días de cooldown
        if channel_id not in self._recently_played:
            return False
        
        last_played = self._recently_played[channel_id].get(tmdb_id)
        if not last_played:
            return False
        
        days_since = (current_date - last_played).days
        return days_since < 7
    
    def _mark_as_played(self, channel_id: str, tmdb_id: int, play_date: date):
        """Mark content as played on a specific date."""
        if channel_id not in self._recently_played:
            self._recently_played[channel_id] = {}
        
        self._recently_played[channel_id][tmdb_id] = play_date
        
        # Save periodically (every 10 items to avoid too many writes)
        if len(self._recently_played[channel_id]) % 10 == 0:
            self._save_cooldown_data()

    
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
                    title_contains=slot_data.get("title_contains", []),
                )
                slots.append(slot)
            
            channel = Channel(
                id=ch_data["id"],
                name=ch_data["name"],
                icon=ch_data.get("icon", "📺"),
                enabled=ch_data.get("enabled", True),
                priority=ch_data.get("priority", 50),
                description=ch_data.get("description"),
                slots=slots,
            )
            self.channels.append(channel)
    
    def _get_seed(self, channel_id: str, target_date: date, slot_index: int) -> int:
        """Generate deterministic seed from channel, date, and slot."""
        seed_string = f"{channel_id}:{target_date.isoformat()}:{slot_index}"
        hash_bytes = hashlib.md5(seed_string.encode()).digest()
        return int.from_bytes(hash_bytes[:4], byteorder='big')
    
    def _filter_pool_by_slot(
        self,
        pool: List[ContentMetadata],
        slot: TimeSlot,
        channel_id: Optional[str] = None
    ) -> List[ContentMetadata]:
        """
        Filter the global pool to get content eligible for a specific slot.
        Uses ContentMetadata.matches_slot_filters() for multi-dimensional matching.
        """
        # Build filter dictionary from slot
        slot_filters = {"channel_id": channel_id}
        
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
        
        if slot.title_contains:
            slot_filters["title_contains"] = slot.title_contains
        
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
        seed: int,
        channel_id: str  # NEW: needed for cooldown tracking
    ) -> List[Program]:
        """
        Fill a time slot with programs from eligible content.
        Uses deterministic shuffling based on seed.
        Prevents content repetition across channels in the same hour.
        Enforces 7-day cooldown for movies on the same channel.
        """
        programs = []
        current_time = slot_start
        target_date = slot_start.date()
        
        # Seed random for deterministic selection
        rng = random.Random(seed)
        
        # Shuffle eligible content deterministically
        shuffled = eligible_content.copy()
        rng.shuffle(shuffled)
        
        content_index = 0
        
        while current_time < slot_end and content_index < len(shuffled):
            content = shuffled[content_index]
            content_index += 1
            
            # Check if content is in cooldown period (movies only)
            if self._is_in_cooldown(channel_id, content.tmdb_id, content.media_type, target_date):
                continue  # Skip, this movie was played recently on this channel
            
            # Check if content is already used in this hour
            current_hour = current_time.hour
            if self._is_content_used(target_date, current_hour, content.tmdb_id):
                continue  # Skip this content, it's already playing on another channel
            
            # Get runtime (use default if not available)
            runtime = content.runtime
            if runtime is None or runtime <= 0:
                runtime = 45 if content.media_type == "tv" else 90
            
            # Calculate program end time
            program_end = current_time + timedelta(minutes=runtime)
            
            # Skip if would overflow slot too much (allow 15 min tolerance)
            if program_end > slot_end + timedelta(minutes=15):
                continue
            
            # Mark content as used for this hour
            self._mark_content_used(target_date, current_hour, content.tmdb_id)
            
            # Mark as played for cooldown tracking
            self._mark_as_played(channel_id, content.tmdb_id, target_date)
            
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
            eligible_content = self._filter_pool_by_slot(self._global_pool, slot, channel_id=channel.id)
            
            if not eligible_content:
                print(f"⚠️ No eligible content for {channel.name} - {slot.label}")
                continue
            
            # Fill slot with programs
            programs = self._fill_slot_with_content(
                slot=slot,
                eligible_content=eligible_content,
                slot_start=slot_start,
                slot_end=slot_end,
                seed=seed,
                channel_id=channel.id  # Pass channel_id for cooldown tracking
            )
            
            all_programs.extend(programs)
        
        # Sort by start time
        all_programs.sort(key=lambda p: p.start_time)
        
        # Cache
        self._schedule_cache[cache_key] = all_programs
        
        # Save cooldown data after generating schedule
        self._save_cooldown_data()
        
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
