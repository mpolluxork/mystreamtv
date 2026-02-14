"""
Content Metadata Layer for MyStreamTV.
Enriched metadata for movies and TV shows with multi-dimensional attributes.
"""
import re
from dataclasses import dataclass, field
from typing import List, Optional, Dict, Any
from datetime import datetime


@dataclass
class ContentMetadata:
    """
    Enriched metadata for a piece of content (movie or TV show).
    Supports multi-dimensional filtering for channel assignment.
    """
    # Core TMDB data
    tmdb_id: int
    title: str
    original_title: str
    media_type: str  # "movie" or "tv"
    overview: str
    
    # Classification
    genres: List[int] = field(default_factory=list)  # TMDB genre IDs
    year: Optional[int] = None
    decade: Optional[int] = None  # 2020, 1990, etc.
    
    # Quality metrics
    vote_average: float = 0.0
    vote_count: int = 0
    is_premium: bool = False  # vote_average >= 7.5
    
    # Discovery attributes
    keywords: List[str] = field(default_factory=list)
    universes: List[str] = field(default_factory=list)  # ["Star Wars", "Marvel"]
    origin_channels: List[str] = field(default_factory=list)  # Channels that discovered this
    
    # People
    director_id: Optional[int] = None
    director_name: Optional[str] = None
    
    # Origin
    origin_countries: List[str] = field(default_factory=list)  # ["US", "MX"]
    original_language: Optional[str] = None
    
    # Content details
    runtime: Optional[int] = None  # Minutes
    release_date: Optional[str] = None
    
    # Availability
    providers: List[Dict[str, Any]] = field(default_factory=list)
    
    # Visual assets
    poster_path: Optional[str] = None
    backdrop_path: Optional[str] = None
    
    def matches_slot_filters(self, slot_filters: Dict[str, Any]) -> bool:
        """
        Check if this content matches the criteria for a specific time slot.
        Robust logic: 
        1. Structural filters MUST match (Type, Era, Rating, People, Blacklist).
        2. Thematic filters (Universe, Keywords, Search) are checked.
        3. If already attributed to the channel, we allow bypassing thematic checks 
           if structural ones pass (Trusted attribution).
        """
        channel_id = slot_filters.get("channel_id")
        is_attributed = channel_id is not None and channel_id in self.origin_channels

        # --- PHASE 1: Structural Filters (Mandatory) ---
        
        # 1. Content type (movie vs tv)
        if slot_filters.get("content_type"):
            if self.media_type != slot_filters["content_type"]:
                return False

        # 2. Decade/Year
        if slot_filters.get("decade"):
            start_year, end_year = slot_filters["decade"]
            if not self.year or not (start_year <= self.year <= end_year):
                return False

        # 3. Quality (Vote average)
        if slot_filters.get("vote_average_min"):
            if (self.vote_average or 0) < slot_filters["vote_average_min"]:
                return False

        # 4. Blacklist (Exclude keywords)
        if slot_filters.get("exclude_keywords"):
            excluded = [k.lower() for k in slot_filters["exclude_keywords"]]
            content_keywords = [k.lower() for k in self.keywords]
            if any(k in content_keywords for k in excluded):
                return False

        # 5. People filter (Director/Actors)
        if slot_filters.get("with_people"):
            has_person_match = False
            for person in slot_filters["with_people"]:
                if isinstance(person, int):
                    if self.director_id == person:
                        has_person_match = True
                        break
                elif isinstance(person, str):
                    if self.director_name and person.lower() in self.director_name.lower():
                        has_person_match = True
                        break
            if not has_person_match:
                return False

        # --- PHASE 2: Attribution Trust ---
        # If it passed structural filters and is already attributed to this channel,
        # we skip the more fragile thematic/textual checks.
        if is_attributed:
            return True

        # --- PHASE 3: Thematic Filters (Theme must Match) ---

        # 1. Universe filter
        if slot_filters.get("universes"):
            required_universes = set(slot_filters["universes"])
            content_universes = set(self.universes)
            if not required_universes.intersection(content_universes):
                # Flexible check: "Batman" matches "The Batman"
                match_found = False
                for req in required_universes:
                    if any(req.lower() in c.lower() or c.lower() in req.lower() for c in content_universes):
                        match_found = True
                        break
                if not match_found:
                    return False

        # 2. Keywords filter
        if slot_filters.get("keywords"):
            required_keywords = [k.lower().strip() for k in slot_filters["keywords"]]
            content_keywords = [k.lower().strip() for k in self.keywords]
            
            # Flexible match: any required keyword is a substring of any content keyword
            found = False
            for req in required_keywords:
                if any(req in ck or ck in req for ck in content_keywords):
                    found = True
                    break
            if not found:
                return False

        # 3. Title/Overview search (Fuzzy / Linguistic awareness)
        if slot_filters.get("title_contains"):
            patterns = [p.lower() for p in slot_filters["title_contains"]]
            # Normalize text: remove non-alphanumeric to bridge "Star Wars:" and "Star Wars "
            text_to_search = re.sub(r'[^a-zA-Z0-9\s]', ' ', (self.title + " " + self.overview).lower())
            
            # Special case mapping for common translation/spelling variations
            flexible_patterns = []
            for p in patterns:
                p_norm = re.sub(r'[^a-zA-Z0-9\s]', ' ', p)
                flexible_patterns.append(p_norm)
                if "episode" in p_norm: flexible_patterns.append(p_norm.replace("episode", "episodio"))
                if "series" in p_norm: flexible_patterns.append(p_norm.replace("series", "serie"))
            
            if not any(pattern in text_to_search for pattern in flexible_patterns):
                return False

        # 4. Genre IDs filter
        if slot_filters.get("genres"):
            required_genres = set(slot_filters["genres"])
            content_genres = set(self.genres)
            if not required_genres.intersection(content_genres):
                return False

        # 5. Production Countries
        if slot_filters.get("production_countries"):
            required_countries = set(slot_filters["production_countries"])
            content_countries = set(self.origin_countries)
            if not any(c in required_countries for c in content_countries):
                return False

        # 6. Original Language
        if slot_filters.get("original_language"):
            if self.original_language != slot_filters["original_language"]:
                return False

        return True
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization."""
        return {
            "tmdb_id": self.tmdb_id,
            "title": self.title,
            "original_title": self.original_title,
            "media_type": self.media_type,
            "overview": self.overview,
            "genres": self.genres,
            "year": self.year,
            "decade": self.decade,
            "vote_average": self.vote_average,
            "vote_count": self.vote_count,
            "is_premium": self.is_premium,
            "keywords": self.keywords,
            "universes": self.universes,
            "origin_channels": self.origin_channels,
            "director_id": self.director_id,
            "director_name": self.director_name,
            "origin_countries": self.origin_countries,
            "original_language": self.original_language,
            "runtime": self.runtime,
            "release_date": self.release_date,
            "providers": self.providers,
            "poster_path": self.poster_path,
            "backdrop_path": self.backdrop_path,
        }

    @staticmethod
    def from_dict(data: Dict[str, Any]) -> "ContentMetadata":
        """Reconstruct ContentMetadata from dictionary."""
        return ContentMetadata(
            tmdb_id=data["tmdb_id"],
            title=data["title"],
            original_title=data["original_title"],
            media_type=data["media_type"],
            overview=data["overview"],
            genres=data.get("genres", []),
            year=data.get("year"),
            decade=data.get("decade"),
            vote_average=data.get("vote_average", 0.0),
            vote_count=data.get("vote_count", 0),
            is_premium=data.get("is_premium", False),
            keywords=data.get("keywords", []),
            universes=data.get("universes", []),
            origin_channels=data.get("origin_channels", []),
            director_id=data.get("director_id"),
            director_name=data.get("director_name"),
            origin_countries=data.get("origin_countries", []),
            original_language=data.get("original_language"),
            runtime=data.get("runtime"),
            release_date=data.get("release_date"),
            providers=data.get("providers", []),
            poster_path=data.get("poster_path"),
            backdrop_path=data.get("backdrop_path"),
        )
