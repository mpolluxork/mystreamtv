# MyStreamTV - Personal EPG for Streaming Platforms

A personalized Electronic Program Guide (EPG) that creates themed TV channels from your streaming services (Netflix, Disney+, HBO Max, Prime Video).

## 🎯 What is MyStreamTV?

MyStreamTV transforms your streaming content into a traditional TV experience with themed channels and scheduled programming. Instead of endless browsing, you get curated channels like "🚀 Sci-Fi Channel", "🎭 Drama Channel", or "😂 Comedy Channel" with content automatically scheduled throughout the day.

## ✨ Features

### Core Functionality
- **18 Themed Channels**: Pre-configured channels covering genres, decades, and special themes
- **Multi-Channel EPG**: All channels visible simultaneously (no day-specific restrictions)
- **Smart Content Discovery**: Automatic content pool building from TMDB API
- **Streaming Integration**: Direct links to Netflix, Disney+, HBO Max, Prime Video
- **Responsive Design**: Works on desktop, tablet, and mobile

### Advanced Features (Recently Implemented)
- **Content Deduplication**: Same content won't appear on multiple channels at the same time
- **7-Day Cooldown System**: Movies won't repeat on the same channel for 7 days (TV shows exempt)
- **Optimized Pool Updates**: Editing one channel only updates that channel's content pool
- **Persistent Cooldown Tracking**: Cooldown data saved to `data/cooldown.json`

### Admin Features
- **Channel Management**: Create, edit, and delete channels via web UI
- **Time Slot Configuration**: Define custom time slots with genre/decade/keyword filters
- **Priority System**: Control channel ordering in the EPG
- **Enable/Disable Channels**: Toggle channels without deleting them

## 🚀 Quick Start

### Prerequisites
- Python 3.10+
- TMDB API Key ([Get one here](https://www.themoviedb.org/settings/api))

### Installation

1. **Clone and navigate to project**:
   ```bash
   cd /home/mpollux/antigravity/mystreamtv
   ```

2. **Create virtual environment and install dependencies**:
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   pip install -r backend/requirements.txt
   ```

3. **Configure TMDB API**:
   Create `secrets.ini` in the project root:
   ```ini
   [tmdb]
   api_key = YOUR_TMDB_API_KEY_HERE
   ```

4. **Start the server**:
   ```bash
   ./start_server.sh
   ```
   
   Or manually:
   ```bash
   source venv/bin/activate
   cd backend
   uvicorn main:app --host 0.0.0.0 --port 8000 --reload
   ```

### Access the Application

- **EPG Interface**: `http://localhost:8000`
- **Admin Console**: `http://localhost:8000/admin.html`
- **From other devices on your network**: `http://YOUR_LOCAL_IP:8000`

## 📁 Project Structure

```
mystreamtv/
├── backend/
│   ├── main.py                 # FastAPI application entry point
│   ├── config.py               # Configuration and settings
│   ├── models/
│   │   └── models.py           # Data models (Channel, TimeSlot, Program)
│   ├── services/
│   │   ├── schedule_engine.py  # Core scheduling logic with cooldown
│   │   ├── tmdb_client.py      # TMDB API client
│   │   ├── content_metadata.py # Content metadata structures
│   │   └── content_pool_builder.py # Content discovery
│   ├── routers/
│   │   ├── epg.py              # EPG endpoints
│   │   └── channel_management.py # Admin endpoints
│   └── migrations/
│       └── remove_day_of_week.py # Migration script
├── frontend/
│   ├── index.html              # EPG interface
│   ├── admin.html              # Channel management UI
│   ├── styles.css              # EPG styles
│   └── admin.js                # Admin functionality
├── data/
│   ├── channel_templates.json  # Channel configurations
│   ├── content_pool.json       # Cached content metadata
│   └── cooldown.json           # Cooldown tracking (auto-generated)
├── start_server.sh             # Server startup script
└── secrets.ini                 # API keys (create this)
```

## 🎨 Channel Examples

- **🚀 Sci-Fi Channel**: Science fiction movies and series
- **🎭 Drama Médico**: Medical dramas
- **😂 Comedia**: Comedy movies and sitcoms
- **🕵️ Detectives**: Crime and mystery content
- **🎬 Cine de los 80s**: 1980s movies
- **🏆 Premiados**: Oscar-nominated and award-winning content
- **And 12 more...**

## 🔧 Configuration

### Channel Template Structure

Channels are defined in `data/channel_templates.json`:

```json
{
  "id": "scifi-channel",
  "name": "🚀 Sci-Fi Channel",
  "icon": "🚀",
  "priority": 50,
  "enabled": true,
  "slots": [
    {
      "start_time": "20:00",
      "end_time": "23:00",
      "label": "Prime Time Sci-Fi",
      "genre_ids": [878],
      "content_type": "movie"
    }
  ]
}
```

### Time Slot Filters

Available filters for time slots:
- `genre_ids`: TMDB genre IDs
- `decade`: Tuple like `[1980, 1989]`
- `keywords`: Search keywords
- `content_type`: `"movie"` or `"tv"`
- `original_language`: Language code (e.g., `"en"`)
- `vote_average_min`: Minimum rating
- `with_people`: Director/actor TMDB IDs
- `universes`: Franchises like `["Star Wars", "Marvel"]`
- `exclude_keywords`: Blacklist keywords
- `is_favorites_only`: Only show content from favorites lists

## 🛠️ API Endpoints

### EPG Endpoints
- `GET /channels` - List all channels
- `GET /guide?hours=6` - Get EPG guide for all channels
- `GET /now-playing` - What's currently playing on all channels
- `GET /channel/{id}/schedule` - Full day schedule for a channel

### Admin Endpoints
- `GET /admin/channels` - Get all channels with full config
- `POST /admin/channels` - Create new channel
- `PUT /admin/channels/{id}` - Update channel
- `DELETE /admin/channels/{id}` - Delete channel
- `POST /admin/reload` - Force pool regeneration

## 🧪 Recent Changes (Feb 2026)

### ✅ Completed Refactoring
1. **Removed `day_of_week` Logic**: All channels now show simultaneously
2. **Optimized Pool Regeneration**: Only updates affected channel when editing
3. **Content Deduplication**: Prevents same content on multiple channels at once
4. **7-Day Cooldown System**: Movies won't repeat on same channel for a week

### 🔄 Pending Features
- Auto-generation of time slots in admin UI
- Favorites channel from text lists (`peliculas.txt`, `series.txt`)

## 📊 Performance

- **Initial Pool Build**: ~30-60 seconds (depends on API rate limits)
- **Single Channel Update**: ~5-10 seconds
- **Schedule Generation**: <1 second (cached)
- **Content Pool Size**: ~2000-5000 items (varies by channel configuration)

## 🐛 Troubleshooting

### Server won't start
```bash
# Check if port 8000 is in use
lsof -i :8000
# Kill the process if needed
kill -9 <PID>
```

### Empty slots in EPG
- Check TMDB API key in `secrets.ini`
- Verify content pool has items: `cat data/content_pool.json | jq length`
- Check server logs for discovery errors

### Can't access from other devices
```bash
# Allow port 8000 through firewall
sudo ufw allow 8000/tcp
# Verify your local IP
hostname -I
```

## 📝 Development

### Running Tests
```bash
source venv/bin/activate
pytest backend/tests/
```

### Code Style
- Follow PEP 8 for Python code
- Use type hints for function signatures
- Document complex logic with comments

## 🤝 Contributing

This is a personal project, but suggestions and improvements are welcome!

## 📄 License

MIT License - Feel free to use and modify for personal use.

## 🙏 Credits

- **TMDB API**: Content metadata and images
- **FastAPI**: Backend framework
- **Streaming Providers**: Netflix, Disney+, HBO Max, Prime Video

---

**Last Updated**: February 2026  
**Version**: 2.0 (Post-Refactoring)
