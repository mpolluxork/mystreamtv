"""
Content Metadata Layer for MyStreamTV.
Enriched metadata for movies and TV shows with multi-dimensional attributes.
"""
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
        Check if this content matches ALL filters defined in a slot.
        
        Args:
            slot_filters: Dictionary of filter criteria from TimeSlot
            
        Returns:
            True if content matches all filters, False otherwise
        """
        # Content type filter
        if slot_filters.get("content_type"):
            if self.media_type != slot_filters["content_type"]:
                return False
        
        # Genre filter (content must have at least one matching genre)
        if slot_filters.get("genres"):
            required_genres = set(slot_filters["genres"])
            content_genres = set(self.genres)
            if not required_genres.intersection(content_genres):
                return False
        
        # Decade filter
        if slot_filters.get("decade"):
            decade_start, decade_end = slot_filters["decade"]
            if not self.year or not (decade_start <= self.year <= decade_end):
                return False
        
        # Rating filter
        if slot_filters.get("vote_average_min"):
            if self.vote_average < slot_filters["vote_average_min"]:
                return False
        
        # Universe filter (content must belong to at least one required universe)
        if slot_filters.get("universes"):
            required_universes = set(slot_filters["universes"])
            content_universes = set(self.universes)
            if not required_universes.intersection(content_universes):
                return False
        
        # Keywords filter (flexible matching - content must have at least one keyword)
        if slot_filters.get("keywords"):
            required_keywords = [kw.lower() for kw in slot_filters["keywords"]]
            content_keywords = [kw.lower() for kw in self.keywords]
            
            # Check if any required keyword is substring of any content keyword
            has_match = False
            for req_kw in required_keywords:
                for cont_kw in content_keywords:
                    if req_kw in cont_kw or cont_kw in req_kw:
                        has_match = True
                        break
                if has_match:
                    break
            
            if not has_match:
                return False
        
        # Exclude keywords (blacklist)
        if slot_filters.get("exclude_keywords"):
            exclude_keywords = [kw.lower() for kw in slot_filters["exclude_keywords"]]
            content_keywords = [kw.lower() for kw in self.keywords]
            
            for excl_kw in exclude_keywords:
                for cont_kw in content_keywords:
                    if excl_kw in cont_kw or cont_kw in excl_kw:
                        return False
        
        # Language filter
        if slot_filters.get("original_language"):
            if self.original_language != slot_filters["original_language"]:
                return False
        
        # Country filter
        if slot_filters.get("production_countries"):
            required_country = slot_filters["production_countries"]
            if required_country not in self.origin_countries:
                return False
        
        # Director filter
        if slot_filters.get("with_people"):
            if self.director_id not in slot_filters["with_people"]:
                return False
        
        # Title/Overview search filter (search in title and synopsis)
        if slot_filters.get("title_contains"):
            search_terms = [term.lower() for term in slot_filters["title_contains"]]
            
            # Combine title and overview for searching
            searchable_text = f"{self.title} {self.overview}".lower()
            
            # Check if ANY search term appears in title or overview
            has_match = False
            for term in search_terms:
                if term in searchable_text:
                    has_match = True
                    break
            
            if not has_match:
                return False
        
        # All filters passed
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
