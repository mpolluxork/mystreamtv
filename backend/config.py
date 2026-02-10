"""
Configuration module for MyStreamTV.
Loads settings from secrets.ini and environment variables.
"""
import configparser
from functools import lru_cache
from pydantic_settings import BaseSettings
from pathlib import Path


class Settings(BaseSettings):
    """Application settings loaded from secrets.ini"""
    TMDB_API_KEY: str
    TMDB_BASE_URL: str = "https://api.themoviedb.org/3"
    TMDB_LANGUAGE: str = "es-MX"
    WATCH_REGION: str = "MX"
    
    # Provider IDs for Mexico (user's subscriptions)
    PROVIDER_NETFLIX: int = 8
    PROVIDER_PRIME: int = 119
    PROVIDER_DISNEY: int = 337
    PROVIDER_HBO_MAX: int = 384
    PROVIDER_PARAMOUNT: int = 531
    PROVIDER_APPLE_TV: int = 2
    PROVIDER_APPLE_TV_STORE: int = 3
    PROVIDER_GOOGLE_PLAY: int = 3
    PROVIDER_MUBI: int = 11
    PROVIDER_PLEX: int = 538
    PROVIDER_PLUTO_TV: int = 300
    PROVIDER_TUBI: int = 283
    PROVIDER_VIX: int = 457
    PROVIDER_YOUTUBE_PREMIUM: int = 188
    PROVIDER_MGM_AMAZON: int = 583
    PROVIDER_UNIVERSAL_AMAZON: int = 582
    PROVIDER_MERCADO_PLAY: int = 423
    
    class Config:
        env_file = ".env"


def load_secrets() -> dict:
    """Load credentials from secrets.ini"""
    config = configparser.ConfigParser()
    secrets_path = Path(__file__).parent.parent / "secrets.ini"
    config.read(secrets_path)
    
    return {
        "TMDB_API_KEY": config.get("credentials", "tmdb_key", fallback=""),
        "TMDB_LANGUAGE": config.get("credentials", "tmdb_language", fallback="es-MX"),
        "WATCH_REGION": config.get("credentials", "watch_region", fallback="MX"),
    }


@lru_cache
def get_settings() -> Settings:
    """Get cached settings instance."""
    secrets = load_secrets()
    return Settings(**secrets)
