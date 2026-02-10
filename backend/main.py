"""
MyStreamTV - EPG-Style Streaming Guide
FastAPI main application entry point.
"""
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pathlib import Path

from routers import epg, channel_management
from services.tmdb_client import get_tmdb_client


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan: startup and shutdown events."""
    # Startup: validate TMDB connection and provider IDs
    print("🚀 MyStreamTV starting up...")
    
    tmdb = get_tmdb_client()
    try:
        providers = await tmdb.validate_provider_ids()
        print(f"✅ Validated MX providers: {providers}")
    except Exception as e:
        print(f"⚠️ Could not validate providers: {e}")
    
    # Pre-build content pool to avoid timeout on first request
    print("🔨 Pre-building content pool...")
    try:
        from routers.epg import get_engine
        global engine
        engine = get_engine()
        await engine.build_global_pool(max_items=1000)  # Moderate size for variety
        if len(engine._global_pool) < 10: # Only expand if pool is empty or very small
            await engine.expand_pool_for_all_channels()
            print(f"✅ Content pool ready and expanded with {len(engine._global_pool)} items")
        else:
            print(f"📦 Using existing pool with {len(engine._global_pool)} items. Use Admin Console to expand.")
    except Exception as e:
        print(f"⚠️ Could not build pool: {e}")
    
    yield
    
    # Shutdown
    print("👋 MyStreamTV shutting down...")
    await tmdb.close_client()


app = FastAPI(
    title="MyStreamTV",
    description="EPG-style streaming guide for eliminating decision paralysis",
    version="1.0.0",
    lifespan=lifespan,
)

# CORS configuration for frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, restrict to specific origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(epg.router, prefix="/api/epg", tags=["EPG"])
app.include_router(channel_management.router, tags=["Channel Management"])

# Serve static frontend files
frontend_path = Path(__file__).parent.parent / "frontend"
if frontend_path.exists():
    app.mount("/", StaticFiles(directory=str(frontend_path), html=True), name="frontend")


@app.get("/health")
async def health_check():
    """Detailed health check."""
    return {
        "status": "healthy",
        "tmdb": "configured",
        "region": "MX",
    }
