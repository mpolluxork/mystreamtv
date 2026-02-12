#!/bin/bash
# MyStreamTV Server Startup Script
# Runs the server accessible from any device on the local network

echo "========================================"
echo "  MyStreamTV - Starting Server (Linux)"
echo "========================================"
echo ""

# Navigate to backend directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/backend"

# Activate virtual environment
echo "Activating virtual environment..."
source venv/bin/activate

# Get local IP address
LOCAL_IP=$(hostname -I | awk '{print $1}')

echo ""
echo "📡 Server will be accessible at:"
echo "   - Local:   http://localhost:8000"
echo "   - Network: http://$LOCAL_IP:8000"
echo ""
echo "📺 EPG Interface:  http://$LOCAL_IP:8000"
echo "⚙️  Admin Console:  http://$LOCAL_IP:8000/admin.html"
echo ""
echo "Press Ctrl+C to stop the server"
echo "================================"
echo ""

# Start uvicorn with network binding
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
