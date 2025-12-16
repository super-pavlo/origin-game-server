# Ubuntu Docker Setup Guide

## Overview

This guide will help you:
1. Install Docker on Ubuntu
2. Set up and run the game server using Docker
3. Configure for external access (Windows Unity client)

## Prerequisites

- Ubuntu 18.04 or later (20.04, 22.04 recommended)
- sudo/root access
- Internet connection

---

## Part 1: Install Docker on Ubuntu

### Step 1: Update System

```bash
sudo apt update
sudo apt upgrade -y
```

### Step 2: Install Required Packages

```bash
sudo apt install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
```

### Step 3: Add Docker's Official GPG Key

```bash
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
```

### Step 4: Set Up Docker Repository

```bash
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

### Step 5: Install Docker Engine

```bash
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

### Step 6: Verify Docker Installation

```bash
# Check Docker version
docker --version

# Test Docker
sudo docker run hello-world
```

### Step 7: Add User to Docker Group (Optional but Recommended)

This allows you to run Docker without `sudo`:

```bash
sudo usermod -aG docker $USER
```

**Important:** Log out and log back in (or run `newgrp docker`) for this to take effect.

### Step 8: Verify Non-Sudo Docker Access

```bash
# After logging back in
docker run hello-world
```

If this works without `sudo`, you're all set!

---

## Part 2: Install Docker Compose (if not included)

Docker Compose might already be installed. Check:

```bash
docker compose version
```

If not installed or you need standalone version:

```bash
# Download Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

# Make executable
sudo chmod +x /usr/local/bin/docker-compose

# Verify
docker-compose --version
```

---

## Part 3: Setup MySQL Database

### Option A: Install MySQL on Ubuntu (Recommended)

```bash
# Install MySQL
sudo apt update
sudo apt install -y mysql-server

# Start MySQL
sudo systemctl start mysql
sudo systemctl enable mysql

# Secure MySQL installation
sudo mysql_secure_installation
```

### Option B: Use MySQL in Docker

```bash
docker run -d \
  --name mysql-server \
  -p 3306:3306 \
  -e MYSQL_ROOT_PASSWORD=root \
  -e MYSQL_DATABASE=ig \
  mysql:8.0
```

### Create Database and User

```bash
# Connect to MySQL
sudo mysql -u root -p
```

In MySQL:
```sql
CREATE DATABASE IF NOT EXISTS ig DEFAULT CHARSET utf8 COLLATE utf8_general_ci;
CREATE DATABASE IF NOT EXISTS log DEFAULT CHARSET utf8 COLLATE utf8_general_ci;
CREATE USER IF NOT EXISTS 'rok'@'%' IDENTIFIED WITH mysql_native_password BY 'Kbsq123!';
GRANT ALL PRIVILEGES ON ig.* TO 'rok'@'%';
GRANT ALL PRIVILEGES ON log.* TO 'rok'@'%';
FLUSH PRIVILEGES;
EXIT;
```

**Note:** We use `'rok'@'%'` (not `localhost`) so Docker container can connect.

### Configure MySQL to Accept Docker Connections

Edit MySQL config:
```bash
sudo nano /etc/mysql/mysql.conf.d/mysqld.cnf
```

Find `bind-address` and change to:
```
bind-address = 0.0.0.0
```

Restart MySQL:
```bash
sudo systemctl restart mysql
```

---

## Part 4: Build Docker Image

```bash
# Navigate to project directory
cd /path/to/origin-game-server

# Build Docker image (takes 5-10 minutes)
docker build --rm -t centos:7 -f work/tool/docker/centos7.Dockerfile ./
```

**Or use the helper.txt command:**
```bash
docker build --rm -t centos:7 -f centos7.Dockerfile ./
```

---

## Part 5: Configure Server for External Access

### Find Ubuntu Server IP

```bash
# Get IP address
ip addr show | grep "inet " | grep -v 127.0.0.1

# Or
hostname -I | awk '{print $1}'
```

### Update Server Configuration

We'll update the configs after starting the container (see Part 6).

---

## Part 6: Start Docker Container and Setup

### Start Container

```bash
# Start container
docker-compose up -d

# Verify container is running
docker ps
```

### Get Container Name/ID

```bash
# Get container name
docker ps --format "{{.Names}}" | grep rok_dev

# Or get container ID
CONTAINER_ID=$(docker ps -q -f name=rok_dev)
echo $CONTAINER_ID
```

### Enter Container

```bash
# Enter container
docker exec -it $(docker ps -q -f name=rok_dev) bash
```

### Inside Container: Install Dependencies

```bash
# Install build dependencies
yum install -y gcc gcc-c++ cmake autoconf make
yum install -y readline-devel pcre-devel zlib-devel

# Install MySQL client (for testing)
yum install -y mysql
```

### Inside Container: Update MySQL Configuration

```bash
cd /root/rok-server

# Update MySQL IP to access Ubuntu MySQL
# If MySQL is on Ubuntu host, use: host.docker.internal
# If MySQL is in another Docker container, use container name
sed -i 's/mysqlip = ".*"/mysqlip = "host.docker.internal"/g' etc/game.conf
sed -i 's/mysqlip = "127.0.0.1"/mysqlip = "host.docker.internal"/g' etc/game.conf
sed -i 's/mysqlip = "192.168.2.73"/mysqlip = "host.docker.internal"/g' etc/game.conf
```

**Note:** `host.docker.internal` allows Docker to access services on the Ubuntu host.

### Inside Container: Update Server IP for External Access

```bash
# Get Ubuntu server IP (from Ubuntu terminal, not container)
# Then update startup scripts

# Get IP first (run this on Ubuntu, not in container)
UBUNTU_IP=$(hostname -I | awk '{print $1}')
echo $UBUNTU_IP

# Then in container, update (replace with actual IP)
UBUNTU_IP="192.168.1.100"  # Replace with your Ubuntu IP

sed -i "s/export CONNECT_IP=\"127.0.0.1\"/export CONNECT_IP=\"$UBUNTU_IP\"/g" etc/start_game.sh
sed -i "s/export CONNECT_REAL_IP=\"127.0.0.1\"/export CONNECT_REAL_IP=\"$UBUNTU_IP\"/g" etc/start_game.sh
sed -i "s/export CONNECT_IP=\"127.0.0.1\"/export CONNECT_IP=\"$UBUNTU_IP\"/g" etc/start_login.sh
sed -i "s/export CONNECT_REAL_IP=\"127.0.0.1\"/export CONNECT_REAL_IP=\"$UBUNTU_IP\"/g" etc/start_login.sh
sed -i "s/export WEB_IP=\"127.0.0.1\"/export WEB_IP=\"0.0.0.0\"/g" etc/start_monitor.sh
```

### Inside Container: Compile Server

```bash
cd /root/rok-server

# Compile (takes 5-10 minutes)
make
```

### Test MySQL Connection from Container

```bash
# Test connection to Ubuntu MySQL
mysql -h host.docker.internal -u rok -pKbsq123! -e "SELECT 1;"
```

If this fails, you may need to:
1. Check MySQL is listening on all interfaces
2. Check firewall rules
3. Use Ubuntu's actual IP instead of `host.docker.internal`

---

## Part 7: Start Servers

### Inside Container: Start All Servers

```bash
cd /root/rok-server

# Start Redis first (required)
bash etc/start_redis.sh
sleep 2

# Start all servers in order
bash etc/start_monitor.sh
sleep 3

bash etc/start_db.sh
sleep 2

bash etc/start_center.sh
sleep 2

bash etc/start_login.sh
sleep 2

bash etc/start_game.sh
sleep 2

bash etc/start_battle.sh
sleep 2

bash etc/start_chat.sh
sleep 2

bash etc/start_push.sh
sleep 2

bash etc/start_log.sh
```

### Verify Servers Are Running

```bash
# Check processes
ps aux | grep co

# Check status
cat ok.txt

# Check logs
tail -f logs/game1.Error.*.log
```

---

## Part 8: Configure Firewall (if needed)

If you can't connect from Windows, check Ubuntu firewall:

```bash
# Check firewall status
sudo ufw status

# Allow required ports
sudo ufw allow 44445/tcp    # Game server
sudo ufw allow 58000/tcp    # Monitor web
sudo ufw allow 57000:57011/tcp  # Internal servers
sudo ufw allow 56000:56011/tcp  # Debug ports

# Enable firewall (if not enabled)
sudo ufw enable
```

---

## Quick Start Script

Create `start_server_ubuntu.sh`:

```bash
#!/bin/bash

echo "=========================================="
echo "Starting Game Server in Docker (Ubuntu)"
echo "=========================================="
echo ""

# Get container
CONTAINER=$(docker ps -q -f name=rok_dev)
if [ -z "$CONTAINER" ]; then
    echo "Starting Docker container..."
    docker-compose up -d
    sleep 5
    CONTAINER=$(docker ps -q -f name=rok_dev)
fi

if [ -z "$CONTAINER" ]; then
    echo "ERROR: Could not start container"
    exit 1
fi

echo "Container: $CONTAINER"
echo ""

# Get Ubuntu IP
UBUNTU_IP=$(hostname -I | awk '{print $1}')
echo "Ubuntu Server IP: $UBUNTU_IP"
echo ""

# Check if compiled
echo "Checking if server is compiled..."
COMPILED=$(docker exec $CONTAINER bash -c "cd /root/rok-server && test -f co && echo 'yes' || echo 'no'")
if [ "$COMPILED" = "no" ]; then
    echo "Compiling server (this may take 5-10 minutes)..."
    docker exec $CONTAINER bash -c "cd /root/rok-server && make"
fi

# Start Redis
echo "Starting Redis..."
docker exec $CONTAINER bash -c "cd /root/rok-server && bash etc/start_redis.sh"
sleep 2

# Start all servers
echo "Starting all servers..."
docker exec $CONTAINER bash -c "cd /root/rok-server && bash etc/start_monitor.sh && sleep 3 && bash etc/start_db.sh && sleep 2 && bash etc/start_center.sh && sleep 2 && bash etc/start_login.sh && sleep 2 && bash etc/start_game.sh && sleep 2 && bash etc/start_battle.sh && sleep 2 && bash etc/start_chat.sh && sleep 2 && bash etc/start_push.sh && sleep 2 && bash etc/start_log.sh"

echo ""
echo "=========================================="
echo "Servers Started!"
echo "=========================================="
echo ""
echo "Game Server: $UBUNTU_IP:44445"
echo "Monitor Web: http://$UBUNTU_IP:58000"
echo ""
echo "View logs: docker exec $CONTAINER bash -c 'cd /root/rok-server && tail -f logs/game1.Error.*.log'"
echo ""
```

Make it executable:
```bash
chmod +x start_server_ubuntu.sh
```

Run it:
```bash
./start_server_ubuntu.sh
```

---

## Useful Commands

### Docker Commands

```bash
# View running containers
docker ps

# View all containers
docker ps -a

# View container logs
docker logs <container_name>

# Stop container
docker-compose down

# Restart container
docker-compose restart

# Remove container
docker-compose down -v
```

### Server Management

```bash
# Enter container
docker exec -it $(docker ps -q -f name=rok_dev) bash

# View server logs
docker exec $(docker ps -q -f name=rok_dev) bash -c "cd /root/rok-server && tail -f logs/game1.Error.*.log"

# Check server status
docker exec $(docker ps -q -f name=rok_dev) bash -c "cd /root/rok-server && cat ok.txt"

# Stop all servers
docker exec $(docker ps -q -f name=rok_dev) bash -c "pkill -f co"

# Check running processes
docker exec $(docker ps -q -f name=rok_dev) bash -c "ps aux | grep co"
```

### Network Commands

```bash
# Check if ports are listening
sudo netstat -tulpn | grep -E '44445|58000|57000'

# Or use ss
sudo ss -tulpn | grep -E '44445|58000|57000'

# Test connection from Ubuntu
curl http://localhost:58000
```

---

## Troubleshooting

### Docker Installation Issues

**Permission denied:**
```bash
# Add user to docker group
sudo usermod -aG docker $USER
# Log out and back in
```

**Docker daemon not running:**
```bash
sudo systemctl start docker
sudo systemctl enable docker
```

### Container Won't Start

```bash
# Check Docker logs
docker-compose logs

# Check if ports are in use
sudo netstat -tulpn | grep 44445
```

### Can't Connect to MySQL from Container

**Test connection:**
```bash
docker exec $(docker ps -q -f name=rok_dev) bash -c "mysql -h host.docker.internal -u rok -pKbsq123! -e 'SELECT 1;'"
```

**If host.docker.internal doesn't work:**
1. Get Ubuntu IP: `hostname -I | awk '{print $1}'`
2. Use that IP instead in `etc/game.conf`
3. Make sure MySQL `bind-address = 0.0.0.0`

### Can't Connect from Windows

1. **Check firewall:**
   ```bash
   sudo ufw status
   sudo ufw allow 44445/tcp
   ```

2. **Check if server is listening:**
   ```bash
   sudo netstat -tulpn | grep 44445
   ```

3. **Test from Ubuntu:**
   ```bash
   curl http://localhost:58000
   ```

4. **Check server IP in Unity client:**
   - Use Ubuntu server's IP address (not localhost)
   - Format: `<UBUNTU_IP>:44445`

### Redis Not Starting

```bash
# Check Redis logs
docker exec $(docker ps -q -f name=rok_dev) bash -c "cd /root/rok-server && tail -20 etc/redis/redis-log-1"
```

---

## Summary

**Complete Setup Steps:**

1. ✅ Install Docker on Ubuntu
2. ✅ Install and configure MySQL
3. ✅ Build Docker image
4. ✅ Start Docker container
5. ✅ Configure server (MySQL IP, external IP)
6. ✅ Compile server
7. ✅ Start all servers
8. ✅ Configure firewall
9. ✅ Connect from Windows Unity client

**Connection Info:**
- **Game Server:** `<UBUNTU_IP>:44445`
- **Monitor Web:** `http://<UBUNTU_IP>:58000`

**Quick Start:**
```bash
# 1. Install Docker
# (Follow Part 1)

# 2. Setup MySQL
# (Follow Part 3)

# 3. Build and start
docker build --rm -t centos:7 -f work/tool/docker/centos7.Dockerfile ./
docker-compose up -d
docker exec -it $(docker ps -q -f name=rok_dev) bash

# 4. Inside container: compile and start
cd /root/rok-server
make
bash etc/start_redis.sh
# ... start other servers
```

---

## Next Steps

1. ✅ Server is running on Ubuntu
2. ✅ Find Ubuntu IP: `hostname -I`
3. ✅ Configure Unity client on Windows to connect to `<UBUNTU_IP>:44445`
4. ✅ Test connection

Good luck! 🚀

