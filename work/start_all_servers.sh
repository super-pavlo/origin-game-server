#!/bin/bash

# Quick Start Script for Mac
# Starts all game servers in the correct order

echo "=========================================="
echo "Starting Game Servers"
echo "=========================================="
echo ""

# Check if server is compiled
if [ ! -f "co" ]; then
    echo "ERROR: Server not compiled!"
    echo "Please run 'make' first"
    exit 1
fi

# Get Mac IP for display
MAC_IP=$(ipconfig getifaddr $(route get default 2>/dev/null | awk '/interface/ { print $2 }' 2>/dev/null))
if [ -z "$MAC_IP" ]; then
    MAC_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -1 | awk '{print $2}')
fi

echo "Server IP: $MAC_IP"
echo ""

# Start servers in order
echo "Starting Monitor Server..."
bash etc/start_monitor.sh
sleep 3

echo "Starting Database Server..."
bash etc/start_db.sh
sleep 2

echo "Starting Center Server..."
bash etc/start_center.sh
sleep 2

echo "Starting Login Server..."
bash etc/start_login.sh
sleep 2

echo "Starting Game Server..."
bash etc/start_game.sh
sleep 2

echo "Starting Battle Server..."
bash etc/start_battle.sh
sleep 2

echo "Starting Chat Server..."
bash etc/start_chat.sh
sleep 2

echo "Starting Push Server..."
bash etc/start_push.sh
sleep 2

echo "Starting Log Server..."
bash etc/start_log.sh
sleep 1

echo ""
echo "=========================================="
echo "All Servers Started!"
echo "=========================================="
echo ""
echo "Server Status:"
ps aux | grep -E "./co etc/" | grep -v grep
echo ""
echo "Connection Info:"
echo "  Game Server: $MAC_IP:44445"
echo "  Monitor Web: http://$MAC_IP:58000"
echo ""
echo "Check status: cat ok.txt"
echo "View logs: tail -f logs/game1.Error.*.log"
echo ""
