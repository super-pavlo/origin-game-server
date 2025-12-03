#!/bin/bash
# Start all game servers in correct order
# Run from work directory

echo "=========================================="
echo "Starting Game Server Cluster"
echo "=========================================="
echo ""

# Check if we're in the right directory
if [ ! -f "co" ]; then
    echo "❌ Error: Must run from work directory!"
    echo "   cd work && ./start_all_servers.sh"
    exit 1
fi

# Make sure co is executable
chmod +x co

# Create logs directory
mkdir -p logs

echo "1/9 Starting Monitor Server (must be first)..."
bash etc/start_monitor.sh
sleep 3

echo "2/9 Starting DB Server..."
bash etc/start_db.sh
sleep 3

echo "3/9 Starting Center Server..."
bash etc/start_center.sh
sleep 3

echo "4/9 Starting Login Server..."
bash etc/start_login.sh
sleep 3

echo "5/9 Starting Game Server (main server)..."
bash etc/start_game.sh
sleep 3

echo "6/9 Starting Battle Server..."
bash etc/start_battle.sh
sleep 3

echo "7/9 Starting Chat Server..."
bash etc/start_chat.sh
sleep 3

echo "8/9 Starting Push Server..."
bash etc/start_push.sh
sleep 3

echo "9/9 Starting Log Server..."
bash etc/start_log.sh
sleep 2

echo ""
echo "=========================================="
echo "✅ All servers started!"
echo "=========================================="
echo ""
echo "Check status:"
echo "  cat ok.txt"
echo ""
echo "Monitor web interface:"
echo "  http://localhost:58000"
echo ""
echo "Game server (for Unity client):"
echo "  IP: $(hostname -I | awk '{print $1}')"
echo "  Port: 44445"
echo ""
echo "View logs:"
echo "  tail -f logs/*.log"
echo ""
echo "Check running processes:"
echo "  ps aux | grep co | grep -v grep"
echo ""

