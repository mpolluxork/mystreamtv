"""
Data models for MyStreamTV EPG system.
"""
from dataclasses import dataclass, field
from datetime import datetime, time, date
from typing import List, Optional, Dict, Any, Tuple
from enum import Enum


class ContentType(str, Enum):
    MOVIE = "movie"
    TV = "tv"
    FILLER = "filler"  # For future trailers/bumpers


@dataclass
class Program:
    """A single program in the EPG schedule."""
    id: str  # Unique schedule ID (not TMDB ID)
    tmdb_id: int
    content_type: ContentType
    title: str
    original_title: str
    overview: str
    runtime_minutes: int
    
    # Timing
    start_time: datetime
    end_time: datetime
    
    # Visual
    poster_path: Optional[str] = None
    backdrop_path: Optional[str] = None
    
    # Metadata
    genres: List[str] = field(default_factory=list)
    release_year: Optional[int] = None
    vote_average: float = 0.0
    slot_label: str = ""
    
    # Streaming
    provider_name: Optional[str] = None
    provider_logo: Optional[str] = None
    deep_link: Optional[str] = None
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "tmdb_id": self.tmdb_id,
            "content_type": self.content_type.value,
            "title": self.title,
            "original_title": self.original_title,
            "overview": self.overview,
            "runtime_minutes": self.runtime_minutes,
            "start_time": self.start_time.isoformat(),
            "end_time": self.end_time.isoformat(),
            "poster_path": self.poster_path,
            "backdrop_path": self.backdrop_path,
            "genres": self.genres,
            "release_year": self.release_year,
            "vote_average": self.vote_average,
            "slot_label": self.slot_label,
            "provider_name": self.provider_name,
            "provider_logo": self.provider_logo,
            "deep_link": self.deep_link,
        }


@dataclass
class TimeSlot:
    """Definition of a time slot within a channel's daily schedule."""
    start_time: time  # e.g., 20:00
    end_time: time    # e.g., 22:00
    label: str        # e.g., "Marcianos"
    
    # Filters
    genre_ids: List[int] = field(default_factory=list)
    decade: Optional[Tuple[int, int]] = None  # (1980, 1989)
    keywords: List[str] = field(default_factory=list)
    
    # Special filters
    filter_type: Optional[str] = None  # e.g., "oscar_nominated"
    content_type: Optional[ContentType] = None
    collections: List[str] = field(default_factory=list) # e.g., ["Star Wars", "The Mandalorian"]
    original_language: Optional[str] = None
    production_countries: Optional[str] = None
    vote_average_min: Optional[float] = None
    with_people: List[int] = field(default_factory=list) # Director/Actor IDs
    
    # NEW: Universe and keyword exclusion filters
    universes: List[str] = field(default_factory=list)  # e.g., ["Star Wars", "Marvel"]
    exclude_keywords: List[str] = field(default_factory=list)  # Blacklist keywords
    title_contains: List[str] = field(default_factory=list)  # Search in title/overview
    is_favorites_only: bool = False  # If True, only show content from favorites lists
    
    def duration_minutes(self) -> int:
        """Calculate slot duration in minutes."""
        start_minutes = self.start_time.hour * 60 + self.start_time.minute
        end_minutes = self.end_time.hour * 60 + self.end_time.minute
        
        # Handle crossing midnight
        if end_minutes <= start_minutes:
            end_minutes += 24 * 60
        
        return end_minutes - start_minutes


@dataclass
class Channel:
    """A themed channel with its schedule template."""
    id: str           # e.g., "scifi-channel"
    name: str         # e.g., "🚀 Sci-Fi Channel"
    icon: str         # Emoji or icon name
    
    slots: List[TimeSlot] = field(default_factory=list)
    
    # Management fields
    enabled: bool = True
    priority: int = 50
    description: Optional[str] = None
    created_at: datetime = field(default_factory=datetime.now)
    updated_at: datetime = field(default_factory=datetime.now)
    
    # Personalization weight (0-1, higher = more personalized content)
    personalization_weight: float = 0.5
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "name": self.name,
            "icon": self.icon,
            "enabled": self.enabled,
            "priority": self.priority,
            "description": self.description,
            "created_at": self.created_at.isoformat(),
            "updated_at": self.updated_at.isoformat(),
            "slots": [
                {
                    "start": s.start_time.strftime("%H:%M"),
                    "end": s.end_time.strftime("%H:%M"),
                    "label": s.label,
                    "content_type": s.content_type.value if s.content_type else None,
                    "genres": s.genre_ids,
                    "decade": list(s.decade) if s.decade else None,
                    "keywords": s.keywords,
                    "exclude_keywords": s.exclude_keywords,
                    "universes": s.universes,
                    "original_language": s.original_language,
                    "production_countries": s.production_countries,
                    "vote_average_min": s.vote_average_min,
                    "with_people": s.with_people,
                }
                for s in self.slots
            ],
        }


@dataclass
class UserPreferences:
    """User preferences extracted from favorites list."""
    # Genre preferences (genre_id -> weight 0-1)
    genres: Dict[int, float] = field(default_factory=dict)
    
    # Decade preferences (decade_start -> weight 0-1)
    decades: Dict[int, float] = field(default_factory=dict)
    
    # Favorite directors (person_id -> name)
    directors: Dict[int, str] = field(default_factory=dict)
    
    # Favorite actors (person_id -> name)
    actors: Dict[int, str] = field(default_factory=dict)
    
    # Related content (tmdb_id -> reason)
    related_content: Dict[int, str] = field(default_factory=dict)
    
    # Raw list of favorite movie IDs
    favorite_ids: List[int] = field(default_factory=list)
    
    def top_genres(self, n: int = 5) -> List[int]:
        """Get top N genre IDs by preference weight."""
        sorted_genres = sorted(
            self.genres.items(), 
            key=lambda x: x[1], 
            reverse=True
        )
        return [g[0] for g in sorted_genres[:n]]
    
    def top_decades(self, n: int = 3) -> List[Tuple[int, int]]:
        """Get top N decades as (start, end) tuples."""
        sorted_decades = sorted(
            self.decades.items(),
            key=lambda x: x[1],
            reverse=True
        )
        return [(d[0], d[0] + 9) for d in sorted_decades[:n]]


# ==================== TMDB Genre ID Reference ====================
# Common genre IDs for quick reference:
GENRE_IDS = {
    "action": 28,
    "adventure": 12,
    "animation": 16,
    "comedy": 35,
    "crime": 80,
    "documentary": 99,
    "drama": 18,
    "family": 10751,
    "fantasy": 14,
    "history": 36,
    "horror": 27,
    "music": 10402,
    "mystery": 9648,
    "romance": 10749,
    "science_fiction": 878,
    "thriller": 53,
    "war": 10752,
    "western": 37,
}
