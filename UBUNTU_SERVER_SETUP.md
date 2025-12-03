# Ubuntu Server Setup Guide for Game Server

## VMware Configuration

### Recommended VM Settings:
- **RAM**: 4-8 GB (minimum 2 GB)
- **CPU**: 2-4 cores
- **Hard Disk**: 30-50 GB (minimum 20 GB)
- **Network**: NAT or Bridged (Bridged recommended if you need to access from Windows host)
- **ISO**: `ubuntu-24.04.3-live-server-amd64.iso`

### Installation Steps:
1. Create new VM in VMware
2. Select "Ubuntu 64-bit"
3. Allocate resources (see above)
4. Mount the Server ISO
5. Install Ubuntu Server (standard installation)
6. **Important**: Enable OpenSSH server during installation
7. Set up a user account (remember the password!)

## Post-Installation Setup

### 1. Update System
```bash
sudo apt update
sudo apt upgrade -y
```

### 2. Install Build Dependencies
```bash
sudo apt install -y \
    gcc \
    g++ \
    cmake \
    autoconf \
    make \
    git \
    build-essential \
    libreadline-dev \
    pcre-devel \
    zlib1g-dev \
    libcurl4-openssl-dev
```

### 3. Install MySQL Server
```bash
sudo apt install -y mysql-server

# Secure MySQL installation
sudo mysql_secure_installation
# Set root password when prompted
```

### 4. Install Redis
```bash
sudo apt install -y redis-server

# Start Redis
sudo systemctl start redis-server
sudo systemctl enable redis-server
```

### 5. Transfer Server Files

**Option A: Using SCP from Windows (PowerShell)**
```powershell
# From Windows PowerShell
scp -r E:\Workspace\Reskin-Unity3D\docker_server\work username@vm-ip:/home/username/
```

**Option B: Using Shared Folder (VMware)**
1. In VMware: VM → Settings → Options → Shared Folders
2. Add shared folder pointing to `E:\Workspace\Reskin-Unity3D\docker_server`
3. In Ubuntu: Files will be in `/mnt/hgfs/...`

**Option C: Using Git (if project is in repo)**
```bash
git clone <your-repo-url>
```

### 6. Setup Database

```bash
# Create database
sudo mysql -u root -p
```

In MySQL:
```sql
CREATE DATABASE IF NOT EXISTS ig DEFAULT CHARSET utf8 COLLATE utf8_general_ci;
CREATE DATABASE IF NOT EXISTS log DEFAULT CHARSET utf8 COLLATE utf8_general_ci;
CREATE USER 'rok'@'localhost' IDENTIFIED BY 'Kbsq123!';
GRANT ALL PRIVILEGES ON ig.* TO 'rok'@'localhost';
GRANT ALL PRIVILEGES ON log.* TO 'rok'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

Import schema:
```bash
cd /path/to/server/work
mysql -u rok -pKbsq123! ig < tool/sql/oc.sql
```

### 7. Configure Server

Edit `work/etc/game.conf`:
```bash
nano work/etc/game.conf
```

Update MySQL settings:
```lua
mysqlip = "127.0.0.1"
mysqlport = 3306
mysqldb = "ig"
mysqluser = "rok"
mysqlpwd = "Kbsq123!"
```

### 8. Compile Server

```bash
cd work
make clean  # Optional: clean previous builds
make
```

This will take 5-10 minutes. Watch for errors.

### 9. Start Servers

**Start in order:**
```bash
cd work

# 1. Monitor (must start first)
bash etc/start_monitor.sh

# Wait 2-3 seconds, then:
bash etc/start_db.sh
bash etc/start_center.sh
bash etc/start_login.sh
bash etc/start_game.sh
bash etc/start_battle.sh
bash etc/start_chat.sh
bash etc/start_push.sh
bash etc/start_log.sh
```

### 10. Verify Servers

```bash
# Check if processes are running
ps aux | grep co

# Check server status
cat ok.txt

# Check logs
tail -f logs/game1.Error.*.log

# Check ports
netstat -tulpn | grep -E '57000|57005|44445'
```

## Access from Windows Host

### SSH Access
```powershell
# Find VM IP address (in Ubuntu)
ip addr show

# SSH from Windows
ssh username@vm-ip-address
```

### Port Forwarding (if using NAT)

In VMware: VM → Settings → Network Adapter → NAT Settings → Port Forwarding

Add these ports:
- 44445 → 44445 (Game Server)
- 58000 → 58000 (Monitor Web)
- 56005 → 56005 (Debug Console)

Then access from Windows:
- Monitor: `http://vm-ip:58000`
- Game Server: `vm-ip:44445`

## Useful Commands

```bash
# Check server status
ps aux | grep co
cat ok.txt

# View logs
tail -f logs/*.log

# Stop all servers
pkill -f co

# Restart MySQL
sudo systemctl restart mysql

# Restart Redis
sudo systemctl restart redis-server

# Check MySQL connection
mysql -u rok -pKbsq123! ig

# Check Redis
redis-cli ping
```

## Troubleshooting

### Compilation Errors
```bash
# Clean and rebuild
make clean
make
```

### Port Already in Use
```bash
# Find process using port
sudo lsof -i :44445
# Kill process
sudo kill -9 <PID>
```

### MySQL Connection Failed
```bash
# Check MySQL is running
sudo systemctl status mysql

# Check MySQL bind address
sudo nano /etc/mysql/mysql.conf.d/mysqld.cnf
# Ensure: bind-address = 127.0.0.1 (or 0.0.0.0 for remote)
```

### Permission Denied
```bash
# Make scripts executable
chmod +x etc/start_*.sh
chmod +x co
```

## Quick Start Script

Create `start_all.sh`:
```bash
#!/bin/bash

cd /path/to/work

echo "Starting Monitor Server..."
bash etc/start_monitor.sh
sleep 2

echo "Starting DB Server..."
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

echo "All servers started!"
echo "Check status: cat ok.txt"
echo "Monitor: http://localhost:58000"
```

Make executable:
```bash
chmod +x start_all.sh
./start_all.sh
```

## Next Steps

1. ✅ Server is running
2. ✅ Test connection from Unity client
3. ✅ Begin reskin work


