#!/usr/bin/env python3
"""
Content Analysis Script for MyStreamTV
Analyzes movies and series from peliculas.txt and series.txt using TMDB metadata
to discover natural groupings and cycles for new channel creation.
"""
import asyncio
import json
import re
from pathlib import Path
from typing import Dict, List, Optional, Set, Tuple
from collections import Counter, defaultdict
from dataclasses import dataclass, asdict
import sys

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent))

from services.tmdb_client import get_tmdb_client


@dataclass
class ContentMetadata:
    """Metadata for a movie or TV show"""
    tmdb_id: int
    title: str
    year: int
    content_type: str  # "movie" or "tv"
    genres: List[str]
    genre_ids: List[int]
    keywords: List[str]
    vote_average: float
    vote_count: int
    popularity: float
    original_language: str
    overview: str
    runtime: Optional[int] = None
    collection_id: Optional[int] = None
    collection_name: Optional[str] = None
    production_companies: List[str] = None
    director: Optional[str] = None
    cast: List[str] = None
    
    def __post_init__(self):
        if self.production_companies is None:
            self.production_companies = []
        if self.cast is None:
            self.cast = []


class ContentAnalyzer:
    """Analyzes content to discover natural groupings and patterns"""
    
    def __init__(self):
        self.client = get_tmdb_client()
        self.movies: List[ContentMetadata] = []
        self.series: List[ContentMetadata] = []
        self.genre_map: Dict[int, str] = {}
        
    async def initialize(self):
        """Load genre mappings"""
        movie_genres = await self.client.get_genres("movie")
        tv_genres = await self.client.get_genres("tv")
        
        for genre in movie_genres + tv_genres:
            self.genre_map[genre["id"]] = genre["name"]
    
    def parse_letterboxd_url(self, url: str) -> Optional[str]:
        """Extract movie slug from Letterboxd URL"""
        # Format: https://boxd.it/XXXX or https://letterboxd.com/film/movie-name/
        match = re.search(r'boxd\.it/([a-zA-Z0-9]+)', url)
        if match:
            return match.group(1)
        match = re.search(r'letterboxd\.com/film/([^/]+)', url)
        if match:
            return match.group(1)
        return None
    
    async def search_movie_by_title_year(self, title: str, year: int) -> Optional[int]:
        """Search for movie by title and year to get TMDB ID"""
        try:
            result = await self.client._request(
                "GET", 
                "/search/movie",
                {"query": title, "year": year, "language": "es-MX"}
            )
            
            if result.get("results"):
                # Return first result's ID
                return result["results"][0]["id"]
            
            # Try without year if no results
            result = await self.client._request(
                "GET",
                "/search/movie", 
                {"query": title, "language": "es-MX"}
            )
            
            if result.get("results"):
                # Find closest year match
                for movie in result["results"]:
                    release_year = movie.get("release_date", "")[:4]
                    if release_year and abs(int(release_year) - year) <= 1:
                        return movie["id"]
                # Return first if no close match
                return result["results"][0]["id"]
                
        except Exception as e:
            print(f"Error searching for {title} ({year}): {e}")
        
        return None
    
    async def search_tv_by_title(self, title: str) -> Optional[int]:
        """Search for TV show by title to get TMDB ID"""
        try:
            result = await self.client._request(
                "GET",
                "/search/tv",
                {"query": title, "language": "es-MX"}
            )
            
            if result.get("results"):
                return result["results"][0]["id"]
                
        except Exception as e:
            print(f"Error searching for TV show {title}: {e}")
        
        return None
    
    async def get_movie_metadata(self, tmdb_id: int, title: str, year: int) -> Optional[ContentMetadata]:
        """Fetch complete metadata for a movie"""
        try:
            details = await self.client.get_movie_details(tmdb_id)
            
            # Extract keywords
            keywords = []
            try:
                kw_result = await self.client._request("GET", f"/movie/{tmdb_id}/keywords")
                keywords = [kw["name"] for kw in kw_result.get("keywords", [])]
            except:
                pass
            
            # Extract director and cast
            credits = details.get("credits", {})
            director = None
            crew = credits.get("crew", [])
            for person in crew:
                if person.get("job") == "Director":
                    director = person.get("name")
                    break
            
            cast = [person["name"] for person in credits.get("cast", [])[:5]]
            
            # Extract collection
            collection = details.get("belongs_to_collection")
            collection_id = collection.get("id") if collection else None
            collection_name = collection.get("name") if collection else None
            
            # Production companies
            companies = [c["name"] for c in details.get("production_companies", [])[:3]]
            
            return ContentMetadata(
                tmdb_id=tmdb_id,
                title=details.get("title", title),
                year=year,
                content_type="movie",
                genres=[self.genre_map.get(g["id"], g["name"]) for g in details.get("genres", [])],
                genre_ids=[g["id"] for g in details.get("genres", [])],
                keywords=keywords,
                vote_average=details.get("vote_average", 0),
                vote_count=details.get("vote_count", 0),
                popularity=details.get("popularity", 0),
                original_language=details.get("original_language", ""),
                overview=details.get("overview", ""),
                runtime=details.get("runtime"),
                collection_id=collection_id,
                collection_name=collection_name,
                production_companies=companies,
                director=director,
                cast=cast
            )
            
        except Exception as e:
            print(f"Error fetching metadata for movie {tmdb_id}: {e}")
            return None
    
    async def get_tv_metadata(self, tmdb_id: int, title: str) -> Optional[ContentMetadata]:
        """Fetch complete metadata for a TV show"""
        try:
            details = await self.client.get_tv_details(tmdb_id)
            
            # Extract keywords
            keywords = []
            try:
                kw_result = await self.client._request("GET", f"/tv/{tmdb_id}/keywords")
                keywords = [kw["name"] for kw in kw_result.get("results", [])]
            except:
                pass
            
            # Extract creators and cast
            credits = details.get("credits", {})
            creators = details.get("created_by", [])
            director = creators[0]["name"] if creators else None
            
            cast = [person["name"] for person in credits.get("cast", [])[:5]]
            
            # Production companies
            companies = [c["name"] for c in details.get("production_companies", [])[:3]]
            
            # Get first air date year
            first_air_date = details.get("first_air_date", "")
            year = int(first_air_date[:4]) if first_air_date else 0
            
            # Average episode runtime
            episode_runtimes = details.get("episode_run_time", [])
            runtime = episode_runtimes[0] if episode_runtimes else None
            
            return ContentMetadata(
                tmdb_id=tmdb_id,
                title=details.get("name", title),
                year=year,
                content_type="tv",
                genres=[self.genre_map.get(g["id"], g["name"]) for g in details.get("genres", [])],
                genre_ids=[g["id"] for g in details.get("genres", [])],
                keywords=keywords,
                vote_average=details.get("vote_average", 0),
                vote_count=details.get("vote_count", 0),
                popularity=details.get("popularity", 0),
                original_language=details.get("original_language", ""),
                overview=details.get("overview", ""),
                runtime=runtime,
                production_companies=companies,
                director=director,
                cast=cast
            )
            
        except Exception as e:
            print(f"Error fetching metadata for TV show {tmdb_id}: {e}")
            return None
    
    async def analyze_movies_file(self, filepath: Path):
        """Parse and analyze peliculas.txt"""
        print(f"\n📽️  Analyzing movies from {filepath.name}...")
        
        with open(filepath, 'r', encoding='utf-8') as f:
            lines = f.readlines()[1:]  # Skip header
        
        for i, line in enumerate(lines, 1):
            parts = line.strip().split(',')
            if len(parts) < 3:
                continue
            
            try:
                title = parts[1]
                year = int(parts[2])
                
                print(f"  [{i}/{len(lines)}] Searching: {title} ({year})")
                
                tmdb_id = await self.search_movie_by_title_year(title, year)
                if not tmdb_id:
                    print(f"    ⚠️  Could not find TMDB ID for {title}")
                    continue
                
                metadata = await self.get_movie_metadata(tmdb_id, title, year)
                if metadata:
                    self.movies.append(metadata)
                    print(f"    ✅ Added: {metadata.title} - {', '.join(metadata.genres)}")
                
                # Rate limiting
                await asyncio.sleep(0.25)
                
            except Exception as e:
                print(f"    ❌ Error processing line {i}: {e}")
                continue
        
        print(f"\n✅ Analyzed {len(self.movies)} movies")
    
    async def analyze_series_file(self, filepath: Path):
        """Parse and analyze series.txt"""
        print(f"\n📺 Analyzing series from {filepath.name}...")
        
        with open(filepath, 'r', encoding='utf-8') as f:
            lines = f.readlines()
        
        # Filter out empty lines and category headers
        series_titles = [
            line.strip() for line in lines 
            if line.strip() and not line.strip().isupper() or len(line.strip().split()) > 3
        ]
        
        for i, title in enumerate(series_titles, 1):
            try:
                print(f"  [{i}/{len(series_titles)}] Searching: {title}")
                
                tmdb_id = await self.search_tv_by_title(title)
                if not tmdb_id:
                    print(f"    ⚠️  Could not find TMDB ID for {title}")
                    continue
                
                metadata = await self.get_tv_metadata(tmdb_id, title)
                if metadata:
                    self.series.append(metadata)
                    print(f"    ✅ Added: {metadata.title} - {', '.join(metadata.genres)}")
                
                # Rate limiting
                await asyncio.sleep(0.25)
                
            except Exception as e:
                print(f"    ❌ Error processing {title}: {e}")
                continue
        
        print(f"\n✅ Analyzed {len(self.series)} series")
    
    def generate_statistics(self) -> Dict:
        """Generate comprehensive statistics and patterns"""
        all_content = self.movies + self.series
        
        # Genre analysis
        genre_counter = Counter()
        for content in all_content:
            genre_counter.update(content.genres)
        
        # Decade analysis
        decade_counter = Counter()
        for content in all_content:
            decade = (content.year // 10) * 10
            decade_counter[f"{decade}s"] += 1
        
        # Keyword analysis
        keyword_counter = Counter()
        for content in all_content:
            keyword_counter.update(content.keywords)
        
        # Collection/Franchise analysis
        collections = defaultdict(list)
        for movie in self.movies:
            if movie.collection_id:
                collections[movie.collection_name].append(movie.title)
        
        # Production company analysis
        company_counter = Counter()
        for content in all_content:
            company_counter.update(content.production_companies)
        
        # Director analysis
        director_counter = Counter()
        for content in all_content:
            if content.director:
                director_counter[content.director] += 1
        
        # Language analysis
        language_counter = Counter()
        for content in all_content:
            language_counter[content.original_language] += 1
        
        # High-rated content
        highly_rated = [
            {"title": c.title, "rating": c.vote_average, "type": c.content_type}
            for c in all_content
            if c.vote_average >= 7.5 and c.vote_count >= 100
        ]
        highly_rated.sort(key=lambda x: x["rating"], reverse=True)
        
        return {
            "summary": {
                "total_movies": len(self.movies),
                "total_series": len(self.series),
                "total_content": len(all_content),
                "year_range": f"{min(c.year for c in all_content)}-{max(c.year for c in all_content)}"
            },
            "genres": {
                "top_genres": dict(genre_counter.most_common(15)),
                "total_unique": len(genre_counter)
            },
            "decades": dict(sorted(decade_counter.items())),
            "keywords": {
                "top_keywords": dict(keyword_counter.most_common(30)),
                "total_unique": len(keyword_counter)
            },
            "collections": {
                name: titles for name, titles in collections.items()
                if len(titles) >= 2
            },
            "production_companies": dict(company_counter.most_common(20)),
            "directors": dict(director_counter.most_common(15)),
            "languages": dict(language_counter.items()),
            "highly_rated": highly_rated[:30]
        }
    
    def suggest_channels(self, stats: Dict) -> List[Dict]:
        """Suggest new channels based on discovered patterns"""
        suggestions = []
        
        # Genre-based channels
        top_genres = stats["genres"]["top_genres"]
        
        # Musical channel
        if "Music" in top_genres or any("musical" in kw.lower() for kw in stats["keywords"]["top_keywords"]):
            suggestions.append({
                "id": "musicals-channel",
                "name": "Musicales",
                "icon": "🎵",
                "description": "Musicales de Broadway y cine",
                "criteria": {
                    "genres": [10402],  # Music genre
                    "keywords": ["musical", "broadway", "singing"]
                },
                "priority": "high"
            })
        
        # Classic comedies
        if "Comedy" in top_genres:
            suggestions.append({
                "id": "classic-comedy-channel",
                "name": "Comedias Clásicas",
                "icon": "🎭",
                "description": "Comedias de los 30s a los 80s",
                "criteria": {
                    "genres": [35],
                    "decade_start": 1930,
                    "decade_end": 1989,
                    "vote_average_min": 7.0
                },
                "priority": "high"
            })
        
        # Sitcoms
        sitcom_keywords = ["sitcom", "workplace", "family"]
        if any(kw in stats["keywords"]["top_keywords"] for kw in sitcom_keywords):
            suggestions.append({
                "id": "sitcoms-channel",
                "name": "Sitcoms",
                "icon": "📺",
                "description": "Series de comedia situacional",
                "criteria": {
                    "genres": [35],
                    "content_type": "tv",
                    "keywords": sitcom_keywords
                },
                "priority": "high"
            })
        
        # Franchises
        for collection_name, titles in stats["collections"].items():
            if len(titles) >= 3:
                suggestions.append({
                    "id": f"{collection_name.lower().replace(' ', '-')}-channel",
                    "name": collection_name,
                    "icon": "🎬",
                    "description": f"Saga completa de {collection_name}",
                    "criteria": {
                        "collection": collection_name,
                        "titles": titles
                    },
                    "priority": "medium"
                })
        
        # Mexican cinema
        if stats["languages"].get("es", 0) > 5:
            suggestions.append({
                "id": "cine-mexicano-channel",
                "name": "Cine de Oro Mexicano",
                "icon": "🇲🇽",
                "description": "Clásicos del cine mexicano",
                "criteria": {
                    "original_language": "es",
                    "production_countries": "MX",
                    "decade_end": 1970
                },
                "priority": "high"
            })
        
        # Decade channels
        for decade, count in stats["decades"].items():
            if count >= 15 and decade not in ["2020s"]:
                suggestions.append({
                    "id": f"{decade}-channel",
                    "name": f"Los {decade}",
                    "icon": "📼",
                    "description": f"Lo mejor de los {decade}",
                    "criteria": {
                        "decade": decade
                    },
                    "priority": "medium"
                })
        
        # Thematic channels based on keywords
        keyword_themes = {
            "time-travel": ("⏰", "Viajes en el Tiempo", ["time travel", "time loop"]),
            "ai-robots": ("🤖", "IA y Robots", ["artificial intelligence", "robot", "android"]),
            "superhero": ("🦸", "Superhéroes", ["superhero", "marvel", "dc comics"]),
            "zombie": ("🧟", "Zombies", ["zombie", "undead", "apocalypse"]),
            "space": ("🚀", "Espacio", ["space", "astronaut", "mars", "alien"]),
        }
        
        for theme_id, (icon, name, keywords) in keyword_themes.items():
            matching_keywords = [kw for kw in keywords if kw in stats["keywords"]["top_keywords"]]
            if matching_keywords:
                suggestions.append({
                    "id": f"{theme_id}-channel",
                    "name": name,
                    "icon": icon,
                    "description": f"Contenido sobre {name.lower()}",
                    "criteria": {
                        "keywords": matching_keywords
                    },
                    "priority": "medium"
                })
        
        # Animation studios
        animation_companies = ["Pixar", "Walt Disney Animation Studios", "DreamWorks Animation"]
        for company in animation_companies:
            if company in stats["production_companies"]:
                suggestions.append({
                    "id": f"{company.lower().replace(' ', '-')}-channel",
                    "name": company.replace(" Animation Studios", "").replace(" Animation", ""),
                    "icon": "🎨",
                    "description": f"Películas de {company}",
                    "criteria": {
                        "production_company": company
                    },
                    "priority": "medium"
                })
        
        # Highly rated / Oscar-worthy
        if len(stats["highly_rated"]) >= 20:
            suggestions.append({
                "id": "masterpieces-channel",
                "name": "Obras Maestras",
                "icon": "🏆",
                "description": "Películas altamente calificadas",
                "criteria": {
                    "vote_average_min": 8.0,
                    "vote_count_min": 1000
                },
                "priority": "high"
            })
        
        return suggestions


async def main():
    """Main analysis workflow"""
    print("=" * 60)
    print("🎬 MyStreamTV Content Analyzer")
    print("=" * 60)
    
    analyzer = ContentAnalyzer()
    
    # Initialize TMDB client
    print("\n🔧 Initializing TMDB client...")
    await analyzer.initialize()
    
    # Paths
    base_path = Path(__file__).parent.parent
    movies_file = base_path / "peliculas.txt"
    series_file = base_path / "series.txt"
    output_dir = base_path / "data"
    output_dir.mkdir(exist_ok=True)
    
    # Analyze content
    if movies_file.exists():
        await analyzer.analyze_movies_file(movies_file)
    else:
        print(f"⚠️  Movies file not found: {movies_file}")
    
    if series_file.exists():
        await analyzer.analyze_series_file(series_file)
    else:
        print(f"⚠️  Series file not found: {series_file}")
    
    # Generate statistics
    print("\n📊 Generating statistics...")
    stats = analyzer.generate_statistics()
    
    # Suggest channels
    print("\n💡 Suggesting new channels...")
    suggestions = analyzer.suggest_channels(stats)
    
    # Save results
    report_path = output_dir / "content_analysis_report.json"
    with open(report_path, 'w', encoding='utf-8') as f:
        json.dump({
            "statistics": stats,
            "channel_suggestions": suggestions,
            "metadata": {
                "movies": [asdict(m) for m in analyzer.movies],
                "series": [asdict(s) for s in analyzer.series]
            }
        }, f, indent=2, ensure_ascii=False)
    
    print(f"\n✅ Analysis complete! Report saved to: {report_path}")
    
    # Print summary
    print("\n" + "=" * 60)
    print("📈 SUMMARY")
    print("=" * 60)
    print(f"Total Movies: {stats['summary']['total_movies']}")
    print(f"Total Series: {stats['summary']['total_series']}")
    print(f"Year Range: {stats['summary']['year_range']}")
    print(f"\nTop 5 Genres:")
    for genre, count in list(stats['genres']['top_genres'].items())[:5]:
        print(f"  • {genre}: {count}")
    print(f"\nChannel Suggestions: {len(suggestions)}")
    for suggestion in suggestions[:10]:
        print(f"  {suggestion['icon']} {suggestion['name']} - {suggestion['description']}")
    
    if len(suggestions) > 10:
        print(f"  ... and {len(suggestions) - 10} more")
    
    print("\n" + "=" * 60)


if __name__ == "__main__":
    asyncio.run(main())
