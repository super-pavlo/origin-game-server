#!/bin/bash

# Mac Server Setup Script
# This script configures the game server to accept connections from external clients

echo "=========================================="
echo "Mac Server Setup Script"
echo "=========================================="
echo ""

# Check if we're in the right directory
if [ ! -f "work/etc/start_game.sh" ]; then
    echo "ERROR: Please run this script from the project root directory"
    echo "Current directory: $(pwd)"
    exit 1
fi

# Get Mac IP address
echo "Detecting Mac IP address..."
MAC_IP=$(ipconfig getifaddr $(route get default 2>/dev/null | awk '/interface/ { print $2 }' 2>/dev/null))

if [ -z "$MAC_IP" ]; then
    # Fallback method
    MAC_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -1 | awk '{print $2}')
fi

if [ -z "$MAC_IP" ]; then
    echo "ERROR: Could not detect Mac IP address"
    echo "Please enter your Mac's IP address manually:"
    read MAC_IP
fi

echo "Detected Mac IP: $MAC_IP"
echo ""

# Confirm IP address
echo "Is this IP address correct? (y/n)"
read -r confirm
if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "Please enter the correct IP address:"
    read MAC_IP
fi

echo ""
echo "Configuring server files with IP: $MAC_IP"
echo ""

# Function to update IP in a file
update_ip_in_file() {
    local file=$1
    if [ -f "$file" ]; then
        # Backup original file
        cp "$file" "${file}.bak"
        
        # Update CONNECT_IP and CONNECT_REAL_IP (macOS sed syntax)
        sed -i '' "s|export CONNECT_IP=\"127.0.0.1\"|export CONNECT_IP=\"$MAC_IP\"|g" "$file"
        sed -i '' "s|export CONNECT_REAL_IP=\"127.0.0.1\"|export CONNECT_REAL_IP=\"$MAC_IP\"|g" "$file"
        
        # Update MONITOR_NODE_IP if present
        sed -i '' "s|export MONITOR_NODE_IP=\"127.0.0.1\"|export MONITOR_NODE_IP=\"$MAC_IP\"|g" "$file"
        
        # Update CLUSTER_IP if present
        sed -i '' "s|export CLUSTER_IP=\"127.0.0.1\"|export CLUSTER_IP=\"$MAC_IP\"|g" "$file"
        
        # Update WEB_IP if present (allow external web access)
        sed -i '' "s|export WEB_IP=\"127.0.0.1\"|export WEB_IP=\"0.0.0.0\"|g" "$file"
        
        echo "  ✓ Updated: $file"
    else
        echo "  ✗ File not found: $file"
    fi
}

# Update all server startup scripts
echo "Updating server startup scripts..."

update_ip_in_file "work/etc/start_game.sh"
update_ip_in_file "work/etc/start_login.sh"
update_ip_in_file "work/etc/start_chat.sh"
update_ip_in_file "work/etc/start_monitor.sh"
update_ip_in_file "work/etc/start_center.sh"
update_ip_in_file "work/etc/start_battle.sh"
update_ip_in_file "work/etc/start_push.sh"
update_ip_in_file "work/etc/start_db.sh"
update_ip_in_file "work/etc/start_log.sh"

echo ""
echo "=========================================="
echo "Configuration Complete!"
echo "=========================================="
echo ""
echo "Server Configuration:"
echo "  Game Server: $MAC_IP:44445"
echo "  Login Server: $MAC_IP:57001"
echo "  Monitor Web UI: http://$MAC_IP:58000"
echo ""
echo "Next Steps:"
echo "  1. Make sure MySQL is running: brew services start mysql"
echo "  2. Compile the server: cd work && make"
echo "  3. Start servers: bash etc/start_monitor.sh (then others)"
echo "  4. Configure Unity client on Windows to connect to: $MAC_IP:44445"
echo ""
echo "Note: Make sure your Mac firewall allows incoming connections on these ports"
echo ""

