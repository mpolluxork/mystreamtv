"""
Content Pool Builder for MyStreamTV.
Refactored to support dynamic discovery for both movies and TV shows.

FIXED ISSUES:
1. Bug en keywords - ahora usa 'keywords' en vez de 'keywords_ids'
2. Búsqueda mejorada por keywords textuales
3. Mejor manejo de universos sin title_patterns
4. Más logging para debugging
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
            {"genres": [10402], "content_type": "movie"},  # Musicales
            {"genres": [878], "content_type": "movie"},    # Sci-Fi
            {"genres": [28], "content_type": "movie"},     # Action
            {"genres": [27], "content_type": "movie"},     # Horror
            {"genres": [35], "content_type": "movie"},     # Comedy
            {"genres": [18], "content_type": "movie"},     # Drama
        ])
    
    if include_tv:
        queries.extend([
            {"genres": [10765], "content_type": "tv"},  # Sci-Fi & Fantasy
            {"genres": [35], "content_type": "tv"},     # Comedy
            {"genres": [18], "content_type": "tv"},     # Drama
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
    
    print(f"✅ Initial pool built with {len(pool)} items")
    return pool


async def discover_content_for_filters(
    tmdb_client, 
    filters: Dict[str, Any], 
    max_results: int = 50
) -> List[ContentMetadata]:
    """
    Perform targeted discovery on TMDB based on specific criteria.
    Supports both 'movie' and 'tv' content types.
    
    FIXED: Ahora maneja correctamente keywords como strings (no solo IDs).
    """
    media_type = filters.get("content_type", filters.get("media_type", "movie"))
    results = []
    seen_ids = set()
    
    # Extract keywords (as strings)
    keywords_text = filters.get("keywords", [])
    
    print(f"🔍 Discovery: {media_type}")
    print(f"   Filters: genres={filters.get('genres')}, decade={filters.get('decade')}, keywords={keywords_text}")
    
    # --- NUEVA LÓGICA: Búsqueda por keywords textuales ---
    if keywords_text:
        print(f"   🔎 Searching by keywords: {keywords_text}")
        for keyword in keywords_text[:3]:  # Limitar a 3 keywords para no saturar
            if len(results) >= max_results:
                break
            
            try:
                # Buscar en TMDB usando el término como query
                search_endpoint = f"/search/{media_type}"
                response = await tmdb_client._request("GET", search_endpoint, {"query": keyword})
                
                items = response.get("results", [])
                print(f"      '{keyword}' → {len(items)} resultados")
                
                for item in items[:20]:  # Tomar solo top 20 por keyword
                    if len(results) >= max_results:
                        break
                    
                    if item["id"] in seen_ids:
                        continue
                    
                    # Verificar disponibilidad
                    providers = await _get_providers(tmdb_client, item["id"], media_type)
                    if not providers:
                        continue
                    
                    # Enriquecer metadata
                    metadata = await _process_item(tmdb_client, item, media_type, providers)
                    
                    # Validar que el keyword realmente esté en overview o título
                    keyword_lower = keyword.lower()
                    if (keyword_lower in metadata.title.lower() or 
                        keyword_lower in metadata.overview.lower() or
                        any(keyword_lower in kw.lower() for kw in metadata.keywords)):
                        results.append(metadata)
                        seen_ids.add(item["id"])
                
                await asyncio.sleep(0.1)  # Rate limiting
                
            except Exception as e:
                print(f"      ⚠️ Error searching '{keyword}': {e}")
    
    # --- BÚSQUEDA POR UNIVERSOS (si están especificados) ---
    if filters.get("universes"):
        from services.universe_detector import UNIVERSE_RULES
        
        print(f"   🌌 Searching by universes: {filters['universes']}")
        
        for universe_name in filters["universes"]:
            if len(results) >= max_results:
                break
            
            if universe_name not in UNIVERSE_RULES:
                continue
            
            rule = UNIVERSE_RULES[universe_name]
            
            # Usar title_patterns si existen
            if "title_patterns" in rule:
                for pattern in rule["title_patterns"][:3]:
                    if len(results) >= max_results:
                        break
                    
                    try:
                        search_endpoint = f"/search/{media_type}"
                        response = await tmdb_client._request("GET", search_endpoint, {"query": pattern})
                        
                        for item in response.get("results", [])[:10]:
                            if len(results) >= max_results:
                                break
                            
                            if item["id"] in seen_ids:
                                continue
                            
                            providers = await _get_providers(tmdb_client, item["id"], media_type)
                            if not providers:
                                continue
                            
                            metadata = await _process_item(tmdb_client, item, media_type, providers)
                            
                            # Verificar que pertenezca al universo
                            if universe_name in metadata.universes:
                                results.append(metadata)
                                seen_ids.add(item["id"])
                        
                        await asyncio.sleep(0.1)
                        
                    except Exception as e:
                        print(f"      ⚠️ Error searching universe '{universe_name}': {e}")
    
    # --- BÚSQUEDA ESTÁNDAR POR DISCOVER (géneros, década, rating, etc.) ---
    try:
        print(f"   📊 Standard discovery (genres, decade, rating)...")
        
        for page in range(1, 4):  # 3 páginas máximo
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
                keywords=[]  # TMDB keywords API requiere IDs, no strings, así que ignoramos aquí
            )
            
            items = response.get("results", [])
            if not items:
                break
            
            print(f"      Page {page} → {len(items)} items")
            
            for item in items:
                if len(results) >= max_results:
                    break
                
                if item["id"] in seen_ids:
                    continue
                
                # Verificar disponibilidad
                providers = await _get_providers(tmdb_client, item["id"], media_type)
                if not providers:
                    continue
                
                # Enriquecer metadata
                metadata = await _process_item(tmdb_client, item, media_type, providers)
                results.append(metadata)
                seen_ids.add(item["id"])
            
            await asyncio.sleep(0.1)
    
    except Exception as e:
        print(f"   ⚠️ Standard discovery error: {e}")
    
    print(f"   ✅ Discovery complete: {len(results)} items found")
    return results


async def _process_item(tmdb_client, item: Dict, media_type: str, providers: List) -> ContentMetadata:
    """
    Process raw TMDB item results into ContentMetadata.
    
    FIXED: Ahora obtiene keywords correctamente.
    """
    # Detectar universos y obtener detalles
    universes, details = await detect_universes(item, tmdb_client)
    
    # Obtener keywords (NUEVO: antes no se llamaba)
    keywords = await _get_keywords(tmdb_client, item["id"], media_type)
    
    # Obtener director (solo para películas)
    director_id = None
    director_name = None
    if media_type == "movie":
        director_id, director_name = await _get_director(tmdb_client, item["id"])
    
    # Extraer año
    release_date = item.get("release_date") or item.get("first_air_date", "")
    year = int(release_date[:4]) if len(release_date) >= 4 else None
    decade = (year // 10) * 10 if year else None
    
    # Filtrar providers contra la lista permitida
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
        keywords=keywords,  # AHORA SÍ INCLUYE KEYWORDS
        universes=universes,
        director_id=director_id,
        director_name=director_name,
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
    """
    Get keywords for content.
    
    FIXED: Ahora realmente se llama desde _process_item.
    """
    try:
        endpoint = f"/{content_type}/{content_id}/keywords"
        result = await tmdb_client._request("GET", endpoint)
        keyword_list = result.get("keywords" if content_type == "movie" else "results", [])
        return [kw["name"] for kw in keyword_list]
    except Exception as e:
        # print(f"Could not fetch keywords for {content_id}: {e}")
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