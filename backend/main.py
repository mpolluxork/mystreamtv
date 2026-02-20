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
        
        initial_size = len(engine._global_pool)
        print(f"📦 Starting with {initial_size} items in pool")
        
        # Only expand if pool seems incomplete
        # A complete pool should have 1000+ items for 18 channels
        MINIMUM_COMPLETE_POOL_SIZE = 800
        
        if initial_size < MINIMUM_COMPLETE_POOL_SIZE:
            print(f"⚠️ Pool seems incomplete ({initial_size} < {MINIMUM_COMPLETE_POOL_SIZE})")
            
            if initial_size < 100:
                # Pool is empty or very small, do full build first
                print("   Building base pool...")
                await engine.build_global_pool(max_items=1000)
            
            # Expand with channel-specific content
            print("   🔍 Expanding pool with channel-specific content...")
            print("   ⏱️  This will take 3-5 minutes (only happens once)...")
            await engine.expand_pool_for_all_channels()
            
            final_size = len(engine._global_pool)
            print(f"✅ Pool expanded: {final_size} items ({final_size - initial_size} new)")
            print(f"💾 Pool saved to content_pool.json (will be reused on next startup)")
        else:
            print(f"✅ Pool is complete ({initial_size} items), skipping expansion")
            print(f"💡 Use Admin Console to force pool refresh if needed")
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

@app.get("/health")
async def health_check():
    """Detailed health check."""
    return {
        "status": "healthy",
        "tmdb": "configured",
        "region": "MX",
    }

# Serve static frontend files
frontend_path = Path(__file__).parent.parent / "frontend"
if frontend_path.exists():
    app.mount("/", StaticFiles(directory=str(frontend_path), html=True), name="frontend")
