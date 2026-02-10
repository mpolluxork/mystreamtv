"""
TMDB API Client for MyStreamTV.
Extended client with watch providers and discover functionality for EPG.
"""
import httpx
import asyncio
import hashlib
import json
from typing import Optional, Dict, Any, List
import sys
from pathlib import Path
sys.path.append(str(Path(__file__).parent.parent))

from config import get_settings

settings = get_settings()


class TMDBClient:
    """Async TMDB API client with Mexico region and provider filtering."""
    
    def __init__(self):
        self.base_url = settings.TMDB_BASE_URL
        self.api_key = settings.TMDB_API_KEY
        self.language = settings.TMDB_LANGUAGE
        self.region = settings.WATCH_REGION
        
        # Provider IDs for Mexico (user's subscriptions)
        self.providers = {
            "netflix": settings.PROVIDER_NETFLIX,
            "prime": settings.PROVIDER_PRIME,
            "disney": settings.PROVIDER_DISNEY,
            "hbo_max": settings.PROVIDER_HBO_MAX,
            "paramount": settings.PROVIDER_PARAMOUNT,
            "apple_tv": settings.PROVIDER_APPLE_TV,
            "apple_tv_store": settings.PROVIDER_APPLE_TV_STORE,
            "google_play": settings.PROVIDER_GOOGLE_PLAY,
            "mubi": settings.PROVIDER_MUBI,
            "plex": settings.PROVIDER_PLEX,
            "pluto_tv": settings.PROVIDER_PLUTO_TV,
            "tubi": settings.PROVIDER_TUBI,
            "vix": settings.PROVIDER_VIX,
            "youtube_premium": settings.PROVIDER_YOUTUBE_PREMIUM,
            "mgm_amazon": settings.PROVIDER_MGM_AMAZON,
            "universal_amazon": settings.PROVIDER_UNIVERSAL_AMAZON,
            "mercado_play": settings.PROVIDER_MERCADO_PLAY,
        }
        self._request_cache = {}
        self._client = httpx.AsyncClient(timeout=30.0)
    
    async def _request(
        self, 
        method: str, 
        endpoint: str, 
        params: Optional[Dict[str, Any]] = None
    ) -> Dict[str, Any]:
        """Make authenticated request to TMDB API with caching."""
        if params is None:
            params = {}
        
        # Generate cache key
        cache_key = f"{method}:{endpoint}:{sorted(params.items())}"
        if cache_key in self._request_cache:
            return self._request_cache[cache_key]

        url = f"{self.base_url}{endpoint}"
        params["api_key"] = self.api_key
        params["language"] = self.language
        
        try:
            response = await self._client.request(method, url, params=params)
            
            if response.status_code == 429:
                retry_after = int(response.headers.get("Retry-After", 2))
                await asyncio.sleep(retry_after)
                return await self._request(method, endpoint, params)
            
            response.raise_for_status()
            data = response.json()
            self._request_cache[cache_key] = data
            return data
            
        except httpx.HTTPStatusError as e:
            print(f"TMDB API Error: {e.response.status_code} - {e.response.text}")
            raise
        except Exception as e:
            print(f"Network Error: {e}")
            raise

    # ==================== Provider Methods ====================
    
    async def get_available_providers(self, content_type: str = "movie") -> List[Dict]:
        """Get list of streaming providers available in Mexico."""
        endpoint = f"/watch/providers/{content_type}"
        result = await self._request("GET", endpoint, {"watch_region": self.region})
        return result.get("results", [])
    
    async def validate_provider_ids(self) -> Dict[str, int]:
        """
        Validate and update provider IDs by synchronizing with misplataformas.txt.
        This replaces the hardcoded list with dynamic discovery.
        """
        user_platforms = []
        current_hash = ""
        
        try:
            platform_file = Path(__file__).parent.parent.parent / "misplataformas.txt"
            # Define cache file in data directory
            cache_file = Path(__file__).parent.parent.parent / "data" / "provider_cache.json"
            
            if platform_file.exists():
                # 1. Calculate MD5 of misplataformas.txt
                with open(platform_file, "rb") as f:
                    content_bytes = f.read()
                    current_hash = hashlib.md5(content_bytes).hexdigest()
                
                # 2. Check if cache exists and is valid
                if cache_file.exists():
                    try:
                        with open(cache_file, "r", encoding="utf-8") as f:
                            cache_data = json.load(f)
                            if cache_data.get("hash") == current_hash:
                                print("📦 Loading provider IDs from cache (no API calls)...")
                                self.providers = cache_data.get("providers", {})
                                return self.providers
                    except Exception as e:
                        print(f"⚠️ Cache read error (ignoring): {e}")

                # If no cache match, read platform names for processing
                content_str = content_bytes.decode("utf-8")
                for line in content_str.splitlines():
                    clean = line.strip()
                    if clean:
                        # Remove (MX) suffix and normalize
                        name_only = clean.split("(")[0].strip().lower()
                        user_platforms.append(name_only)
                print(f"📋 Loaded {len(user_platforms)} platforms from {platform_file.name}")
                
            else:
                print(f"⚠️ Platform file not found at {platform_file}. Using hardcoded defaults.")
                return self.providers
        except Exception as e:
            print(f"⚠️ Error reading platform file: {e}")
            return self.providers

        # 3. Fetch official TMDB providers for Mexico (API Call)
        print("🌍 Fetching available providers from TMDB (MX)...")
        tmdb_providers = await self.get_available_providers("movie")
        tmdb_map = {p["provider_name"].lower(): p["provider_id"] for p in tmdb_providers}
        tmdb_names = list(tmdb_map.keys())
        
        # 4. Match user platforms to TMDB IDs
        from difflib import get_close_matches
        
        matched_providers = {}
        print(f"🔍 Matching {len(user_platforms)} user platforms against TMDB...")
        
        for user_plat in user_platforms:
            # Try exact match
            if user_plat in tmdb_map:
                matched_providers[user_plat] = tmdb_map[user_plat]
                print(f"  ✅ Exact: '{user_plat}' -> {tmdb_map[user_plat]}")
                continue
            
            # Try fuzzy match
            matches = get_close_matches(user_plat, tmdb_names, n=1, cutoff=0.6)
            if matches:
                best_match = matches[0]
                matched_providers[user_plat] = tmdb_map[best_match]
                print(f"  ✅ Fuzzy: '{user_plat}' ~= '{best_match}' -> {tmdb_map[best_match]}")
            else:
                print(f"  ❌ No match for: '{user_plat}'")
                
        # Update self.providers if we found matches
        if matched_providers:
            self.providers = matched_providers
            print(f"✅ Active providers updated: {len(self.providers)} providers linked.")
            
            # 5. Save to Cache
            try:
                cache_data = {
                    "hash": current_hash,
                    "providers": matched_providers
                }
                cache_file.parent.mkdir(parents=True, exist_ok=True)
                with open(cache_file, "w", encoding="utf-8") as f:
                    json.dump(cache_data, f, indent=2)
                print(f"💾 Provider cache saved to {cache_file.name}")
            except Exception as e:
                print(f"⚠️ Failed to save cache: {e}")
        else:
            print("⚠️ No providers matched! Keeping defaults to avoid empty pool.")
            
        return self.providers

    # ==================== Discover Methods ====================
    
    async def discover_by_slot(
        self,
        genre_ids: List[int],
        decade_start: Optional[int] = None,
        decade_end: Optional[int] = None,
        provider_ids: Optional[List[int]] = None,
        content_type: str = "movie",
        keywords: Optional[List[int]] = None,
        page: int = 1,
        original_language: Optional[str] = None,
        production_countries: Optional[str] = None,
        vote_average_min: Optional[float] = None,
        with_people: Optional[List[int]] = None,
    ) -> Dict[str, Any]:
        """
        Discover content matching slot criteria, filtered by MX providers.
        """
        params = {
            "watch_region": self.region,
            "sort_by": "popularity.desc",
            "page": page,
            "include_adult": False,
        }
        
        # Genre filter
        if genre_ids:
            params["with_genres"] = ",".join(map(str, genre_ids))
        
        # Date range filter
        date_field = "primary_release_date" if content_type == "movie" else "first_air_date"
        if decade_start:
            params[f"{date_field}.gte"] = f"{decade_start}-01-01"
        if decade_end:
            params[f"{date_field}.lte"] = f"{decade_end}-12-31"
        
        # People filter (Director/Actor)
        if with_people:
            params["with_people"] = ",".join(map(str, with_people))
            
        # Language and Country
        if original_language:
            params["with_original_language"] = original_language
        if production_countries:
            params["with_origin_country"] = production_countries
            
        # Rating
        if vote_average_min:
            params["vote_average.gte"] = vote_average_min
        
        # Provider filter (OR logic with pipe separator)
        if provider_ids:
            params["with_watch_providers"] = "|".join(map(str, provider_ids))
        else:
            # Default: all configured providers from user subscriptions
            all_providers = list(self.providers.values())
            params["with_watch_providers"] = "|".join(map(str, all_providers))
        
        # Monetization filter: Only show content that is included in subscriptions (flatrate), free, or ad-supported (ads)
        # UPDATED: Added 'rent' and 'buy' to support transactional platforms like Apple TV Store and Google Play
        params["with_watch_monetization_types"] = "flatrate|free|ads|rent|buy"
        
        # Keyword filter
        if keywords:
            params["with_keywords"] = "|".join(map(str, keywords))
        
        endpoint = f"/discover/{content_type}"
        return await self._request("GET", endpoint, params)

    async def search_keywords(self, query: str) -> List[Dict]:
        """Search for keyword IDs by text."""
        result = await self._request("GET", "/search/keyword", {"query": query})
        return result.get("results", [])

    async def search_person(self, query: str) -> List[Dict]:
        """Search for person IDs by name."""
        result = await self._request("GET", "/search/person", {"query": query})
        return result.get("results", [])

    # ==================== Details Methods ====================
    
    async def get_movie_details(self, movie_id: int) -> Dict[str, Any]:
        """Get full movie details including runtime and images."""
        return await self._request(
            "GET", 
            f"/movie/{movie_id}", 
            {"append_to_response": "watch/providers,images,credits"}
        )
    
    async def get_tv_details(self, tv_id: int) -> Dict[str, Any]:
        """Get TV show details including episode runtime."""
        return await self._request(
            "GET",
            f"/tv/{tv_id}",
            {"append_to_response": "watch/providers,images,credits"}
        )
    
    async def get_watch_providers(
        self, 
        content_id: int, 
        content_type: str = "movie"
    ) -> Dict[str, Any]:
        """Get watch providers for specific content in Mexico."""
        result = await self._request(
            "GET", 
            f"/{content_type}/{content_id}/watch/providers"
        )
        # Return only Mexico providers
        return result.get("results", {}).get(self.region, {})

    # ==================== Genre Methods ====================
    
    async def get_genres(self, content_type: str = "movie") -> List[Dict]:
        """Get list of genres with IDs."""
        result = await self._request("GET", f"/genre/{content_type}/list")
        return result.get("genres", [])

    # ==================== Collection Methods ====================

    async def search_collection_movies(self, collection_query: str) -> List[Dict]:
        """
        Search for a collection by name or ID and return all its movies.
        Supports "10" (as string) or "Star Wars - Colección".
        """
        # 1. Determine if it's already an ID
        if collection_query.isdigit():
            collection_id = int(collection_query)
        else:
            search_result = await self._request("GET", "/search/collection", {"query": collection_query})
            results = search_result.get("results", [])
            
            if not results:
                print(f"No collection found for: {collection_query}")
                return []
            collection_id = results[0]["id"]
        
        # 2. Get collection details (contains the parts/movies)
        try:
            collection_details = await self._request("GET", f"/collection/{collection_id}")
            movies = collection_details.get("parts", [])
            
            # Sort movies by release date if possible
            movies.sort(key=lambda x: x.get("release_date", ""))
            
            return movies
        except httpx.HTTPStatusError as e:
            if e.response.status_code == 404:
                print(f"Collection ID {collection_id} ({collection_query}) not found, skipping...")
                return []
            raise

    async def filter_by_availability(self, programs: List[Dict], content_type: str = "movie") -> List[Dict]:
        """Filter a list of programs to include only those available on user's platforms."""
        if not programs:
            return []
            
        available_programs = []
        # Check sequentially, stop when we have enough (faster than checking all)
        for p in programs[:20]:  # Check up to 20
            try:
                providers = await self.get_watch_providers(p["id"], content_type)
                if providers:
                    available_programs.append(p)
                    # Early termination: stop once we have enough content
                    if len(available_programs) >= 5:
                        break
            except Exception:
                # Skip any program that causes errors
                continue
                    
        return available_programs

    async def close_client(self):
        """Close the persistent httpx client."""
        await self._client.aclose()


# Singleton instance
_client: Optional[TMDBClient] = None


def get_tmdb_client() -> TMDBClient:
    """Get or create TMDB client singleton."""
    global _client
    if _client is None:
        _client = TMDBClient()
    return _client
