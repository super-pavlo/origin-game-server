# Quick Start Guide for Windows 11

## Prerequisites

1. **Docker Desktop for Windows**
   - Download: https://www.docker.com/products/docker-desktop
   - Install and ensure it's running
   - Enable WSL 2 backend (recommended)

2. **MySQL Server** (if not using Docker)
   - Download: https://dev.mysql.com/downloads/mysql/
   - Or use Docker: `docker run -d -p 3306:3306 -e MYSQL_ROOT_PASSWORD=root mysql:8.0`

3. **Redis** (optional, can use Docker)
   - Or use Docker: `docker run -d -p 6379:6379 redis:latest`

## Step-by-Step Setup

### Step 1: Check Docker is Running

```powershell
docker --version
docker ps
```

### Step 2: Build and Start Docker Container

```powershell
# Navigate to project directory
cd E:\Workspace\Reskin-Unity3D\docker_server

# Build Docker image (first time only)
docker build -t centos:7 -f Dockerfile .

# Start container
docker-compose up -d

# Verify container is running
docker ps
```

### Step 3: Enter Container and Compile

```powershell
# Enter the container
docker exec -it docker_server-rok_dev-1 bash

# Inside container, navigate to server directory
cd /root/rok-server

# Install build dependencies (if not already installed)
yum install -y gcc gcc-c++ cmake autoconf make
yum install -y readline-devel pcre-devel zlib-devel

# Compile the server (this may take 5-10 minutes)
make
```

### Step 4: Configure Database

**Option A: Use existing MySQL (update config)**

Edit `work/etc/game.conf` and update MySQL settings:
```lua
mysqlip = "host.docker.internal"  -- Use this to access Windows MySQL from Docker
mysqlport = 3306
mysqldb = "ig"
mysqluser = "root"
mysqlpwd = "your_password"
```

**Option B: Setup MySQL in Docker**

```powershell
# Start MySQL container
docker run -d --name mysql-server -p 3306:3306 -e MYSQL_ROOT_PASSWORD=root -e MYSQL_DATABASE=ig mysql:8.0

# Import database schema
docker exec -i mysql-server mysql -uroot -proot ig < work/tool/sql/oc.sql
```

### Step 5: Start Servers (In Order)

**Inside the Docker container:**

```bash
# 1. Monitor Server (must start first)
bash etc/start_monitor.sh

# Wait 2-3 seconds, then:
# 2. Database Server
bash etc/start_db.sh

# 3. Center Server
bash etc/start_center.sh

# 4. Login Server
bash etc/start_login.sh

# 5. Game Server (main server)
bash etc/start_game.sh

# 6. Battle Server
bash etc/start_battle.sh

# 7. Chat Server
bash etc/start_chat.sh

# 8. Push Server
bash etc/start_push.sh

# 9. Log Server
bash etc/start_log.sh
```

### Step 6: Verify Servers Are Running

```bash
# Check if processes are running
ps aux | grep co

# Check server status
cat ok.txt

# Check logs for errors
tail -f logs/game1.Error.*.log
```

### Step 7: Access Monitor Web Interface

Open browser: `http://localhost:58000`

## Quick Start Script (PowerShell)

Save this as `start_server.ps1`:

```powershell
# Start Docker container
Write-Host "Starting Docker container..." -ForegroundColor Green
docker-compose up -d

Start-Sleep -Seconds 5

# Compile if needed
Write-Host "Checking if server is compiled..." -ForegroundColor Green
docker exec docker_server-rok_dev-1 bash -c "cd /root/rok-server && if [ ! -f co ]; then make; fi"

# Start all servers
Write-Host "Starting all servers..." -ForegroundColor Green
docker exec docker_server-rok_dev-1 bash -c @"
cd /root/rok-server
bash etc/start_monitor.sh && sleep 2
bash etc/start_db.sh && sleep 2
bash etc/start_center.sh && sleep 2
bash etc/start_login.sh && sleep 2
bash etc/start_game.sh && sleep 2
bash etc/start_battle.sh && sleep 2
bash etc/start_chat.sh && sleep 2
bash etc/start_push.sh && sleep 2
bash etc/start_log.sh
"@

Write-Host "`nServers started! Check status:" -ForegroundColor Green
Write-Host "  Monitor: http://localhost:58000" -ForegroundColor Yellow
Write-Host "  Game Server: localhost:44445" -ForegroundColor Yellow
Write-Host "  Logs: docker exec -it docker_server-rok_dev-1 bash -c 'cd /root/rok-server && tail -f logs/game1.Error.*.log'" -ForegroundColor Yellow
```

Run with:
```powershell
.\start_server.ps1
```

## Troubleshooting

### Port Already in Use

```powershell
# Check what's using port 44445
netstat -ano | findstr :44445

# Kill process (replace PID)
taskkill /PID <PID> /F
```

### Docker Container Not Starting

```powershell
# Check Docker logs
docker-compose logs

# Restart Docker Desktop
# Or rebuild container
docker-compose down
docker-compose up -d
```

### Compilation Errors

```powershell
# Clean and rebuild
docker exec docker_server-rok_dev-1 bash -c "cd /root/rok-server && make clean && make"
```

### MySQL Connection Issues

```powershell
# Test MySQL connection from container
docker exec docker_server-rok_dev-1 bash -c "mysql -h host.docker.internal -u root -p"
```

### Server Won't Start

1. Check logs: `docker exec docker_server-rok_dev-1 bash -c "cd /root/rok-server && tail -20 logs/*.log"`
2. Check MySQL is running
3. Check Redis is running (if configured)
4. Verify ports are not blocked by Windows Firewall

## Stopping Servers

```powershell
# Stop all servers (inside container)
docker exec docker_server-rok_dev-1 bash -c "pkill -f co"

# Stop and remove container
docker-compose down
```

## Useful Commands

```powershell
# View all logs
docker exec docker_server-rok_dev-1 bash -c "cd /root/rok-server && tail -f logs/*.log"

# Check server status
docker exec docker_server-rok_dev-1 bash -c "cd /root/rok-server && cat ok.txt"

# Access container shell
docker exec -it docker_server-rok_dev-1 bash

# Restart a specific server
docker exec docker_server-rok_dev-1 bash -c "cd /root/rok-server && bash etc/start_game.sh"
```

## Next Steps

1. ✅ Server is running
2. ✅ Connect Unity client to `localhost:44445`
3. ✅ Test login and basic gameplay
4. ✅ Begin reskin work


