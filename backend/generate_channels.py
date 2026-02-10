#!/usr/bin/env python3
"""
Channel Generator Script for MyStreamTV
Converts analysis results into channel_templates.json format
"""
import json
from pathlib import Path
from typing import Dict, List


# TMDB Genre ID mapping
GENRE_MAP = {
    "Acción": 28,
    "Aventura": 12,
    "Animación": 16,
    "Comedia": 35,
    "Crimen": 80,
    "Documental": 99,
    "Drama": 18,
    "Familia": 10751,
    "Fantasía": 14,
    "Historia": 36,
    "Terror": 27,
    "Música": 10402,
    "Misterio": 9648,
    "Romance": 10749,
    "Ciencia ficción": 878,
    "Película de TV": 10770,
    "Suspense": 53,
    "Bélica": 10752,
    "Western": 37,
    # TV Genres
    "Action & Adventure": 10759,
    "Sci-Fi & Fantasy": 10765,
    "Kids": 10762,
    "News": 10763,
    "Reality": 10764,
    "Soap": 10766,
    "Talk": 10767,
    "War & Politics": 10768
}


def create_channel_from_suggestion(suggestion: Dict, day_of_week: int) -> Dict:
    """Convert a channel suggestion into a full channel template"""
    
    channel_id = suggestion["id"]
    name = suggestion["name"]
    icon = suggestion["icon"]
    description = suggestion["description"]
    criteria = suggestion["criteria"]
    
    # Base channel structure
    channel = {
        "id": channel_id,
        "name": name,
        "icon": icon,
        "day_of_week": day_of_week,
        "slots": []
    }
    
    # Create slots based on criteria type
    if "collection" in criteria:
        # Franchise/Collection channel - marathon all day
        channel["slots"] = create_marathon_slots(criteria)
    
    elif "decade" in criteria:
        # Decade channel
        channel["slots"] = create_decade_slots(criteria)
    
    elif "keywords" in criteria and "musical" in str(criteria["keywords"]).lower():
        # Musical channel
        channel["slots"] = create_musical_slots(criteria)
    
    elif "original_language" in criteria and criteria["original_language"] == "es":
        # Mexican cinema channel
        channel["slots"] = create_mexican_cinema_slots(criteria)
    
    elif "vote_average_min" in criteria and criteria["vote_average_min"] >= 8.0:
        # Masterpieces channel
        channel["slots"] = create_masterpieces_slots(criteria)
    
    elif "keywords" in criteria:
        # Thematic channel (time travel, AI, etc.)
        channel["slots"] = create_thematic_slots(criteria, name)
    
    elif "production_company" in criteria:
        # Studio channel (Pixar, etc.)
        channel["slots"] = create_studio_slots(criteria)
    
    else:
        # Generic genre-based channel
        channel["slots"] = create_generic_slots(criteria)
    
    return channel


def create_marathon_slots(criteria: Dict) -> List[Dict]:
    """Create all-day marathon slots for franchises"""
    return [
        {
            "start": "00:00",
            "end": "00:00",
            "label": f"Maratón {criteria.get('collection', 'Saga')}",
            "content_type": "movie",
            "collection": criteria.get("collection")
        }
    ]


def create_decade_slots(criteria: Dict) -> List[Dict]:
    """Create slots for decade-based channels"""
    decade = criteria["decade"]
    decade_start = int(decade.replace("s", ""))
    decade_end = decade_start + 9
    
    return [
        {
            "start": "06:00",
            "end": "12:00",
            "genres": [28, 12],  # Action & Adventure
            "decade": [decade_start, decade_end],
            "label": f"Acción {decade}",
            "content_type": "movie"
        },
        {
            "start": "12:00",
            "end": "16:00",
            "genres": [35],  # Comedy
            "decade": [decade_start, decade_end],
            "label": f"Comedia {decade}",
            "content_type": "movie"
        },
        {
            "start": "16:00",
            "end": "20:00",
            "genres": [18],  # Drama
            "decade": [decade_start, decade_end],
            "label": f"Drama {decade}",
            "content_type": "movie"
        },
        {
            "start": "20:00",
            "end": "00:00",
            "genres": [878, 14],  # Sci-Fi & Fantasy
            "decade": [decade_start, decade_end],
            "label": f"Sci-Fi {decade}",
            "content_type": "movie"
        },
        {
            "start": "00:00",
            "end": "06:00",
            "decade": [decade_start, decade_end],
            "label": f"Madrugada {decade}",
            "content_type": "movie"
        }
    ]


def create_musical_slots(criteria: Dict) -> List[Dict]:
    """Create slots for musical channel"""
    return [
        {
            "start": "06:00",
            "end": "10:00",
            "genres": [10402],
            "decade": [1930, 1969],
            "label": "Musicales Clásicos",
            "content_type": "movie"
        },
        {
            "start": "10:00",
            "end": "14:00",
            "genres": [10402],
            "keywords": ["broadway"],
            "label": "Broadway",
            "content_type": "movie"
        },
        {
            "start": "14:00",
            "end": "18:00",
            "genres": [10402],
            "decade": [1970, 1989],
            "label": "Musicales 70s-80s",
            "content_type": "movie"
        },
        {
            "start": "18:00",
            "end": "22:00",
            "genres": [10402],
            "decade": [1990, 2030],
            "label": "Musicales Modernos",
            "content_type": "movie"
        },
        {
            "start": "22:00",
            "end": "00:00",
            "genres": [10402],
            "label": "Musicales Románticos",
            "content_type": "movie"
        },
        {
            "start": "00:00",
            "end": "06:00",
            "genres": [10402],
            "label": "Maratón Musical",
            "content_type": "movie"
        }
    ]


def create_mexican_cinema_slots(criteria: Dict) -> List[Dict]:
    """Create slots for Mexican cinema channel"""
    return [
        {
            "start": "06:00",
            "end": "12:00",
            "original_language": "es",
            "production_countries": "MX",
            "decade": [1930, 1959],
            "label": "Época de Oro Temprana",
            "content_type": "movie"
        },
        {
            "start": "12:00",
            "end": "18:00",
            "original_language": "es",
            "production_countries": "MX",
            "decade": [1940, 1959],
            "label": "Época de Oro",
            "content_type": "movie"
        },
        {
            "start": "18:00",
            "end": "22:00",
            "original_language": "es",
            "production_countries": "MX",
            "genres": [35],
            "label": "Comedia Mexicana",
            "content_type": "movie"
        },
        {
            "start": "22:00",
            "end": "00:00",
            "original_language": "es",
            "production_countries": "MX",
            "label": "Cine Mexicano Moderno",
            "content_type": "movie"
        },
        {
            "start": "00:00",
            "end": "06:00",
            "original_language": "es",
            "production_countries": "MX",
            "label": "Maratón Mexicano",
            "content_type": "movie"
        }
    ]


def create_masterpieces_slots(criteria: Dict) -> List[Dict]:
    """Create slots for highly-rated masterpieces channel"""
    return [
        {
            "start": "06:00",
            "end": "10:00",
            "genres": [18],
            "vote_average_min": 8.0,
            "label": "Dramas Aclamados",
            "content_type": "movie"
        },
        {
            "start": "10:00",
            "end": "14:00",
            "vote_average_min": 8.0,
            "decade": [1930, 1979],
            "label": "Clásicos Inmortales",
            "content_type": "movie"
        },
        {
            "start": "14:00",
            "end": "18:00",
            "genres": [878, 28],
            "vote_average_min": 8.0,
            "label": "Acción Perfecta",
            "content_type": "movie"
        },
        {
            "start": "18:00",
            "end": "22:00",
            "vote_average_min": 8.2,
            "label": "Obras Maestras",
            "content_type": "movie"
        },
        {
            "start": "22:00",
            "end": "00:00",
            "genres": [18],
            "vote_average_min": 8.0,
            "content_type": "tv",
            "label": "Series Aclamadas"
        },
        {
            "start": "00:00",
            "end": "06:00",
            "vote_average_min": 7.8,
            "label": "Grandes Películas",
            "content_type": "movie"
        }
    ]


def create_thematic_slots(criteria: Dict, theme_name: str) -> List[Dict]:
    """Create slots for thematic channels (time travel, AI, etc.)"""
    keywords = criteria.get("keywords", [])
    
    return [
        {
            "start": "06:00",
            "end": "12:00",
            "keywords": keywords,
            "content_type": "movie",
            "label": f"{theme_name} Clásicas"
        },
        {
            "start": "12:00",
            "end": "16:00",
            "keywords": keywords,
            "content_type": "tv",
            "label": f"Series de {theme_name}"
        },
        {
            "start": "16:00",
            "end": "20:00",
            "keywords": keywords,
            "decade": [2000, 2030],
            "content_type": "movie",
            "label": f"{theme_name} Modernas"
        },
        {
            "start": "20:00",
            "end": "00:00",
            "keywords": keywords,
            "vote_average_min": 7.0,
            "content_type": "movie",
            "label": f"Lo Mejor de {theme_name}"
        },
        {
            "start": "00:00",
            "end": "06:00",
            "keywords": keywords,
            "content_type": "movie",
            "label": f"Maratón {theme_name}"
        }
    ]


def create_studio_slots(criteria: Dict) -> List[Dict]:
    """Create slots for studio-based channels (Pixar, etc.)"""
    studio = criteria.get("production_company", "")
    
    return [
        {
            "start": "06:00",
            "end": "12:00",
            "production_company": studio,
            "genres": [16],
            "label": f"{studio} Clásicos",
            "content_type": "movie"
        },
        {
            "start": "12:00",
            "end": "18:00",
            "production_company": studio,
            "genres": [16, 10751],
            "label": f"{studio} Familia",
            "content_type": "movie"
        },
        {
            "start": "18:00",
            "end": "22:00",
            "production_company": studio,
            "vote_average_min": 7.5,
            "label": f"Lo Mejor de {studio}",
            "content_type": "movie"
        },
        {
            "start": "22:00",
            "end": "06:00",
            "production_company": studio,
            "label": f"Maratón {studio}",
            "content_type": "movie"
        }
    ]


def create_generic_slots(criteria: Dict) -> List[Dict]:
    """Create generic slots for other channel types"""
    genres = criteria.get("genres", [])
    
    return [
        {
            "start": "06:00",
            "end": "12:00",
            "genres": genres,
            "content_type": "movie",
            "label": "Mañana"
        },
        {
            "start": "12:00",
            "end": "18:00",
            "genres": genres,
            "content_type": "tv",
            "label": "Tarde - Series"
        },
        {
            "start": "18:00",
            "end": "22:00",
            "genres": genres,
            "content_type": "movie",
            "label": "Prime Time"
        },
        {
            "start": "22:00",
            "end": "06:00",
            "genres": genres,
            "content_type": "movie",
            "label": "Maratón Nocturno"
        }
    ]


def main():
    """Generate channel templates from analysis"""
    print("=" * 60)
    print("🎬 MyStreamTV Channel Generator")
    print("=" * 60)
    
    # Load analysis report
    base_path = Path(__file__).parent.parent
    report_path = base_path / "data" / "content_analysis_report.json"
    
    print(f"\n📖 Loading analysis from: {report_path}")
    with open(report_path, 'r', encoding='utf-8') as f:
        report = json.load(f)
    
    suggestions = report["channel_suggestions"]
    print(f"Found {len(suggestions)} channel suggestions")
    
    # Filter and prioritize suggestions
    print("\n🎯 Selecting channels to generate...")
    
    # Priority channels to create
    priority_channels = [
        "musicals-channel",
        "cine-mexicano-channel",
        "masterpieces-channel",
        "1980s-channel",
        "1990s-channel",
        "time-travel-channel",
        "ai-robots-channel",
        "superhero-channel",
    ]
    
    # Also include major franchises
    franchise_keywords = ["star-wars", "marvel", "batman", "james-bond", "rocky"]
    
    selected_suggestions = []
    for suggestion in suggestions:
        channel_id = suggestion["id"]
        
        # Include if high priority
        if channel_id in priority_channels:
            selected_suggestions.append(suggestion)
            print(f"  ✅ {suggestion['icon']} {suggestion['name']} (priority)")
        
        # Include major franchises
        elif any(keyword in channel_id for keyword in franchise_keywords):
            selected_suggestions.append(suggestion)
            print(f"  ✅ {suggestion['icon']} {suggestion['name']} (franchise)")
    
    print(f"\n📝 Generating {len(selected_suggestions)} new channels...")
    
    # Generate channels
    new_channels = []
    for i, suggestion in enumerate(selected_suggestions):
        # Assign day of week (cycling through 0-6)
        day_of_week = i % 7
        channel = create_channel_from_suggestion(suggestion, day_of_week)
        new_channels.append(channel)
        print(f"  {i+1}. {channel['icon']} {channel['name']} - Day {day_of_week}")
    
    # Save to new file
    output = {"channels": new_channels}
    output_path = base_path / "data" / "suggested_channels.json"
    
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(output, f, indent=4, ensure_ascii=False)
    
    print(f"\n✅ Generated channels saved to: {output_path}")
    print(f"\n💡 Next steps:")
    print(f"  1. Review the suggested channels in {output_path.name}")
    print(f"  2. Manually merge desired channels into channel_templates.json")
    print(f"  3. Test EPG generation with new channels")
    print("\n" + "=" * 60)


if __name__ == "__main__":
    main()
