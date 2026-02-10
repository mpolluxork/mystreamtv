"""
Content Pool Builder for MyStreamTV.
Refactored to support dynamic discovery for both movies and TV shows.
"""
from typing import List, Dict, Any, Optional
import asyncio
from services.content_metadata import ContentMetadata
from services.universe_detector import detect_universes


async def build_content_pool(
    tmdb_client,
    max_items: int = 1000,
    include_movies: bool = True,
    include_tv: bool = True
) -> List[ContentMetadata]:
    """
    Build a global pool of available content from TMDB using broad queries.
    """
    print(f"🔨 Building initial content pool (max {max_items} items)...")
    
    pool: List[ContentMetadata] = []
    seen_ids: set = set()
    
    # Broad base queries for initial variety
    queries = []
    
    if include_movies:
        queries.extend([
            {"original_language": "es", "content_type": "movie"}, 
            {"production_countries": "MX", "content_type": "movie"},
            {"genres": [18, 35], "content_type": "movie", "original_language": "es"},
            {"genres": [10402], "content_type": "movie", "fetch_details": True}, 
            {"genres": [878], "content_type": "movie"},
            {"genres": [27], "content_type": "movie"},
        ])
    
    if include_tv:
        queries.extend([
            {"genres": [10765], "content_type": "tv"},
            {"genres": [35], "content_type": "tv"},
            {"genres": [18], "content_type": "tv"},
        ])
    
    for query in queries:
        if len(pool) >= max_items:
            break
            
        results = await discover_content_for_filters(tmdb_client, query, max_results=100)
        for metadata in results:
            if len(pool) >= max_items:
                break
            
            combined_id = (metadata.tmdb_id, metadata.media_type)
            if combined_id not in seen_ids:
                pool.append(metadata)
                seen_ids.add(combined_id)
                
    return pool


async def discover_content_for_filters(
    tmdb_client, 
    filters: Dict[str, Any], 
    max_results: int = 50
) -> List[ContentMetadata]:
    """
    Perform targeted discovery on TMDB based on specific criteria.
    Supports both 'movie' and 'tv' content types.
    """
    media_type = filters.get("content_type", filters.get("media_type", "movie"))
    results = []
    seen_ids = set()
    
    # TMDB keyword IDs for special universes if they are mentioned by name
    # This helps but we should also rely on raw queries
    
    print(f"🔍 Discovery: {media_type} with filters {filters}...")
    
    # Handle targeted universe discovery
    targeted_keywords = set(filters.get("keywords_ids", []))
    search_queries = []
    
    if filters.get("universes"):
        from services.universe_detector import UNIVERSE_RULES
        for uni in filters["universes"]:
            if uni in UNIVERSE_RULES:
                rule = UNIVERSE_RULES[uni]
                # If we have title patterns, use them as search queries
                if "title_patterns" in rule:
                    search_queries.extend(rule["title_patterns"][:3])
                # We could also use keyword search to get IDs here, but let's try search first
                # for simple universe discovery.
    
    try:
        # If we have specific search queries, use them
        if search_queries:
            for query in search_queries:
                if len(results) >= max_results: break
                print(f"🔎 Searching TMDB for universe term: {query}")
                search_method = tmdb_client._request
                endpoint = f"/search/{media_type}"
                response = await search_method("GET", endpoint, {"query": query})
                for item in response.get("results", []):
                    if item["id"] not in seen_ids:
                        providers = await _get_providers(tmdb_client, item["id"], media_type)
                        if providers:
                            metadata = await _process_item(tmdb_client, item, media_type, providers)
                            if any(u in metadata.universes for u in filters["universes"]):
                                results.append(metadata)
                                seen_ids.add(item["id"])
                    if len(results) >= max_results: break

        # standard discovery loop
        for page in range(1, 4):
            if len(results) >= max_results:
                break
                
            response = await tmdb_client.discover_by_slot(
                genre_ids=filters.get("genres", []),
                decade_start=filters.get("decade")[0] if filters.get("decade") and isinstance(filters.get("decade"), (list, tuple)) else None,
                decade_end=filters.get("decade")[1] if filters.get("decade") and isinstance(filters.get("decade"), (list, tuple)) else None,
                content_type=media_type,
                page=page,
                original_language=filters.get("original_language"),
                production_countries=filters.get("production_countries"),
                vote_average_min=filters.get("vote_average_min"),
                with_people=filters.get("with_people", []),
                keywords=list(targeted_keywords)
            )
            
            items = response.get("results", [])
            if not items:
                break
                
            for item in items:
                if len(results) >= max_results:
                    break
                    
                if item["id"] in seen_ids:
                    continue
                    
                # Verify availability in MX
                providers = await _get_providers(tmdb_client, item["id"], media_type)
                if not providers:
                    continue
                    
                # Enrich metadata
                metadata = await _process_item(tmdb_client, item, media_type, providers)
                results.append(metadata)
                seen_ids.add(item["id"])
                
            await asyncio.sleep(0.1) # Respect rate limits
            
    except Exception as e:
        print(f"⚠️ Discovery Error: {e}")
        
    return results


async def _process_item(tmdb_client, item: Dict, media_type: str, providers: List) -> ContentMetadata:
    """Process raw TMDB item results into ContentMetadata."""
    # Detect universes and get details (runtime, etc.)
    universes, details = await detect_universes(item, tmdb_client)
    
    # Extract year
    release_date = item.get("release_date") or item.get("first_air_date", "")
    year = int(release_date[:4]) if len(release_date) >= 4 else None
    decade = (year // 10) * 10 if year else None
    
    # Fetch keywords (optional if we want to be faster, but good for filtering)
    # For now, let's keep it minimal for performance unless needed
    
    # Filter providers against the allowed set
    allowed_provider_ids = set(tmdb_client.providers.values())
    filtered_providers = [
        p for p in providers 
        if p.get("provider_id") in allowed_provider_ids
    ]
    
    return ContentMetadata(
        tmdb_id=item["id"],
        title=item.get("title") or item.get("name", ""),
        original_title=item.get("original_title") or item.get("original_name", ""),
        media_type=media_type,
        overview=item.get("overview", ""),
        genres=item.get("genre_ids", []),
        year=year,
        decade=decade,
        vote_average=item.get("vote_average", 0.0),
        vote_count=item.get("vote_count", 0),
        is_premium=item.get("vote_average", 0.0) >= 7.5,
        universes=universes,
        origin_countries=item.get("origin_country", []),
        original_language=item.get("original_language"),
        release_date=release_date,
        providers=filtered_providers,
        poster_path=item.get("poster_path"),
        backdrop_path=item.get("backdrop_path"),
        runtime=details.get("runtime") if media_type == "movie" else (details.get("episode_run_time") or [None])[0]
    )


async def _get_providers(tmdb_client, content_id: int, content_type: str) -> List[Dict[str, Any]]:
    """Get available providers for content, filtered by user subscriptions."""
    try:
        providers_data = await tmdb_client.get_watch_providers(content_id, content_type)
        if not providers_data:
            return []
        
        user_provider_ids = set(tmdb_client.providers.values())
        providers = []
        seen_ids = set()
        
        for category in ["flatrate", "ads", "free"]:
            if category in providers_data:
                for provider in providers_data[category]:
                    p_id = provider.get("provider_id")
                    if p_id and p_id in user_provider_ids and p_id not in seen_ids:
                        providers.append({
                            "provider_id": p_id,
                            "provider_name": provider.get("provider_name"),
                            "logo_path": provider.get("logo_path"),
                        })
                        seen_ids.add(p_id)
        return providers
    except Exception:
        return []


async def _get_keywords(tmdb_client, content_id: int, content_type: str) -> List[str]:
    """Get keywords for content."""
    try:
        endpoint = f"/{content_type}/{content_id}/keywords"
        result = await tmdb_client._request("GET", endpoint)
        keyword_list = result.get("keywords" if content_type == "movie" else "results", [])
        return [kw["name"] for kw in keyword_list]
    except Exception:
        return []


async def _get_director(tmdb_client, movie_id: int) -> tuple:
    """Get director ID and name for a movie."""
    try:
        credits = await tmdb_client._request("GET", f"/movie/{movie_id}/credits")
        crew = credits.get("crew", [])
        for person in crew:
            if person.get("job") == "Director":
                return person.get("id"), person.get("name")
        return None, None
    except Exception:
        return None, None
