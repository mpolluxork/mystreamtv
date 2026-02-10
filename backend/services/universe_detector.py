"""
Universe Detector for MyStreamTV.
Automatically detects which fictional universes/franchises content belongs to.
"""
from typing import List, Dict, Any, Optional
import asyncio


# Universe detection rules
UNIVERSE_RULES = {
    "Star Wars": {
        "collection_ids": [10],  # Star Wars Collection
        "keywords": ["star wars", "jedi", "sith", "skywalker", "mandalorian"],
        "title_patterns": ["Star Wars", "Mandalorian", "Andor", "Ahsoka", "Boba Fett", "Obi-Wan"],
    },
    "Star Trek": {
        "collection_ids": [151],  # Star Trek Collection
        "keywords": ["star trek", "starfleet", "vulcan", "klingon"],
        "title_patterns": ["Star Trek", "Strange New Worlds", "Lower Decks", "Picard", "Discovery"],
    },
    "Marvel Cinematic Universe": {
        "collection_ids": [86311, 131295, 131292, 618529],  # MCU collections
        "keywords": ["marvel cinematic universe", "mcu", "avengers"],
        "companies": [420],  # Marvel Studios
        "title_patterns": ["Avengers", "Iron Man", "Captain America", "Thor", "Guardians"],
    },
    "DC Extended Universe": {
        "keywords": ["dc extended universe", "dceu"],
        "companies": [9993, 429],  # DC Entertainment, DC Comics
        "title_patterns": ["Batman", "Superman", "Wonder Woman", "Justice League", "Aquaman"],
    },
    "James Bond": {
        "collection_ids": [645],  # James Bond Collection
        "keywords": ["james bond", "007"],
        "title_patterns": ["James Bond", "007"],
    },
    "Rocky-verse": {
        "collection_ids": [1575],  # Rocky Collection
        "keywords": ["rocky balboa"],
        "title_patterns": ["Rocky", "Creed"],
    },
    "Planet of the Apes": {
        "collection_ids": [1709, 173710],
        "keywords": ["planet of the apes"],
        "title_patterns": ["Planet of the Apes"],
    },
    "Matrix": {
        "collection_ids": [2344],
        "keywords": ["the matrix"],
        "title_patterns": ["Matrix"],
    },
    "Mission Impossible": {
        "collection_ids": [87359],
        "keywords": ["mission impossible"],
        "title_patterns": ["Mission: Impossible", "Mission Impossible"],
    },
    "Fast & Furious": {
        "collection_ids": [9485],
        "keywords": ["fast and furious"],
        "title_patterns": ["Fast & Furious", "Fast and Furious"],
    },
    "Harry Potter": {
        "collection_ids": [1241],
        "keywords": ["harry potter", "hogwarts"],
        "title_patterns": ["Harry Potter"],
    },
    "Lord of the Rings": {
        "collection_ids": [119],
        "keywords": ["lord of the rings", "middle earth"],
        "title_patterns": ["Lord of the Rings", "Hobbit"],
    },
    "Jurassic Park": {
        "collection_ids": [328],
        "keywords": ["jurassic park", "jurassic world"],
        "title_patterns": ["Jurassic"],
    },
}


async def detect_universes(
    content_data: Dict[str, Any],
    tmdb_client,
    detailed_data: Optional[Dict[str, Any]] = None
) -> List[str]:
    """
    Detect which universes/franchises this content belongs to.
    
    Args:
        content_data: Basic TMDB data (from discover/search)
        tmdb_client: TMDBClient instance for additional queries
        detailed_data: Optional pre-fetched detailed data
        
    Returns:
        Tuple of (List of universe names, detailed_data dictionary)
    """
    detected_universes = []
    
    # Get content details if not provided
    if not detailed_data:
        try:
            media_type = "movie" if "title" in content_data else "tv"
            if media_type == "movie":
                detailed_data = await tmdb_client.get_movie_details(content_data["id"])
            else:
                detailed_data = await tmdb_client.get_tv_details(content_data["id"])
        except Exception as e:
            print(f"Warning: Could not fetch details for {content_data.get('title', content_data.get('name'))}: {e}")
            detailed_data = content_data
    
    # Get keywords
    try:
        keywords_data = await tmdb_client._request(
            "GET",
            f"/{'movie' if 'title' in content_data else 'tv'}/{content_data['id']}/keywords"
        )
        keywords = [kw["name"].lower() for kw in keywords_data.get("keywords" if "title" in content_data else "results", [])]
    except Exception:
        keywords = []
    
    # Extract data for matching
    title = (content_data.get("title") or content_data.get("name", "")).lower()
    original_title = (content_data.get("original_title") or content_data.get("original_name", "")).lower()
    
    # Collection membership (movies only)
    belongs_to_collection = detailed_data.get("belongs_to_collection")
    collection_id = belongs_to_collection["id"] if belongs_to_collection else None
    
    # Production companies
    production_companies = detailed_data.get("production_companies", [])
    company_ids = [c["id"] for c in production_companies]
    
    # Check each universe
    for universe_name, rules in UNIVERSE_RULES.items():
        matched = False
        
        # Check collection membership
        if collection_id and "collection_ids" in rules:
            if collection_id in rules["collection_ids"]:
                matched = True
        
        # Check keywords
        if not matched and "keywords" in rules:
            for rule_keyword in rules["keywords"]:
                for content_keyword in keywords:
                    if rule_keyword in content_keyword:
                        matched = True
                        break
                if matched:
                    break
        
        # Check title patterns with word boundaries to avoid false positives (e.g., "Andor" in "Resplandor")
        if not matched and "title_patterns" in rules:
            import re
            for pattern in rules["title_patterns"]:
                pattern_lower = pattern.lower()
                # Use regex for word boundaries \b
                if re.search(rf"\b{re.escape(pattern_lower)}\b", title) or \
                   re.search(rf"\b{re.escape(pattern_lower)}\b", original_title):
                    matched = True
                    break
        
        # Check production companies
        if not matched and "companies" in rules:
            if any(company_id in rules["companies"] for company_id in company_ids):
                matched = True
        
        if matched:
            detected_universes.append(universe_name)
    
    return detected_universes, detailed_data


def get_universe_icon(universe_name: str) -> str:
    """Get emoji icon for a universe."""
    icons = {
        "Star Wars": "⭐",
        "Star Trek": "🖖",
        "Marvel Cinematic Universe": "🦸",
        "DC Extended Universe": "🦇",
        "James Bond": "🕵️",
        "Rocky-verse": "🥊",
        "Planet of the Apes": "🦍",
        "Matrix": "💊",
        "Mission Impossible": "🎯",
        "Fast & Furious": "🏎️",
        "Harry Potter": "⚡",
        "Lord of the Rings": "💍",
        "Jurassic Park": "🦖",
    }
    return icons.get(universe_name, "🎬")
