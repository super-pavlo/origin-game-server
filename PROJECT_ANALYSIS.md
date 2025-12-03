# Game Server Project Analysis

## 1. Project Overview Based on Job Posting

### Game Type
Based on the YouTube video link and server architecture, this appears to be a **multiplayer strategy/war game** similar to:
- Real-time strategy (RTS) elements
- Alliance/guild systems
- Battle mechanics
- Resource management
- Building/territory systems

### Current State
- **Client**: Unity 3D (2D rendering, no URP support)
- **Server**: Skynet-based Lua server (this repository)
- **Architecture**: Multi-server distributed system

### Reskin Requirements
The client wants to:
1. Replace ALL visual assets (UI, characters, environment, effects)
2. Convert from 2D to 3D with URP support
3. Use new paid assets:
   - Poly Fantasy Pack (3D props)
   - Low Poly Animated Fantasy Creatures
4. Ensure animations work properly
5. Modify assets to fit game mechanics

---

## 2. Server Architecture Analysis

### Technology Stack
- **Framework**: Skynet (lightweight online game framework)
- **Language**: Lua (server logic) + C/C++ (core libraries)
- **Database**: MySQL (primary), Redis (caching)
- **Protocol**: Sproto (binary protocol)
- **Navigation**: Recast/Detour (pathfinding for battles)

### Server Components

The server consists of **9 different server types** that work together:

#### 1. **Monitor Server** (Port 57000)
- Central monitoring and coordination
- Web interface for server management
- Cluster node management

#### 2. **Login Server** (Port 57001)
- User authentication
- Account management
- Initial connection handling

#### 3. **Center Server** (Port 57002)
- Cross-server data management
- Guild/alliance management
- Ranking systems
- Global configuration

#### 4. **DB Server** (Port 57004)
- Database operations
- Data persistence
- MySQL connection pooling

#### 5. **Game Server** (Port 57005, Client Port 44445)
- **Main game logic server**
- Player state management
- Game world simulation
- Client connections (up to 10,000 concurrent)
- This is the PRIMARY server clients connect to

#### 6. **Battle Server** (Port 57006)
- Battle calculations
- Combat logic
- Pathfinding for battles
- Real-time battle processing

#### 7. **Push Server** (Port 57007)
- Push notifications
- Real-time updates to clients

#### 8. **Chat Server** (Port 57009)
- Chat system
- Message routing
- Chat history

#### 9. **Log Server** (Port 57011)
- Logging and analytics
- Event tracking
- Debug information

### Communication Flow

```
Client → Game Server (44445) → [Internal Cluster Communication]
                                ├─→ DB Server (data)
                                ├─→ Battle Server (combat)
                                ├─→ Chat Server (messages)
                                ├─→ Center Server (guilds/global)
                                └─→ Monitor Server (coordination)
```

### Key Features
- **AOI (Area of Interest)**: Spatial awareness system
- **Navigation Mesh**: Pathfinding for units
- **Hotfix System**: Live code updates
- **Web Interface**: Monitor server dashboard
- **Debug Console**: Telnet-based debugging (ports 56000-56011)

---

## 3. How the Server Works

### Startup Sequence

1. **Monitor Server** starts first (coordinates cluster)
2. **DB Server** starts (database connections)
3. **Center Server** starts (global services)
4. **Login Server** starts (authentication)
5. **Game Server** starts (main game logic)
6. **Battle Server** starts (combat processing)
7. **Chat Server** starts (messaging)
8. **Push Server** starts (notifications)
9. **Log Server** starts (logging)

### Data Flow

1. **Client connects** to Game Server on port 44445
2. **Game Server** authenticates via Login Server
3. **Player data** loaded from DB Server
4. **Game state** synchronized with Center Server
5. **Battles** processed by Battle Server
6. **Chat messages** routed through Chat Server
7. **Events** logged to Log Server

### Configuration System

- **common.conf**: Base Skynet configuration
- **game.conf**: Game server specific config
- **cluster_*.lua**: Server cluster definitions
- **start_*.sh**: Individual server startup scripts

---

## 4. Running the Server on Windows 11

### ⚠️ IMPORTANT: This server is designed for Linux

The server is **NOT natively compatible with Windows** because:
- Uses Linux-specific binaries (`.so` files)
- Requires Linux build tools (gcc, make, cmake)
- Uses bash scripts for startup
- Skynet framework is Linux-based

### Option 1: Docker (Recommended)

The project includes Docker setup:

```powershell
# 1. Build the Docker image
docker build -t centos:7 -f Dockerfile .

# 2. Start the container
docker-compose up -d

# 3. Enter the container
docker exec -it docker_server-rok_dev-1 bash

# 4. Inside container, navigate to server
cd /root/rok-server

# 5. Compile the server (first time only)
make

# 6. Start servers (in order)
bash etc/start_monitor.sh
bash etc/start_db.sh
bash etc/start_center.sh
bash etc/start_login.sh
bash etc/start_game.sh
bash etc/start_battle.sh
bash etc/start_chat.sh
bash etc/start_push.sh
bash etc/start_log.sh
```

### Option 2: WSL2 (Windows Subsystem for Linux)

```powershell
# 1. Install WSL2 (if not already installed)
wsl --install

# 2. Install Ubuntu/Debian
wsl --install -d Ubuntu

# 3. Inside WSL, install dependencies
sudo apt update
sudo apt install -y gcc g++ cmake autoconf make
sudo apt install -y libreadline-dev zlib1g-dev

# 4. Navigate to project
cd /mnt/e/Workspace/Reskin-Unity3D/docker_server/work

# 5. Compile
make

# 6. Start servers
bash etc/start_monitor.sh
# ... (start other servers)
```

### Option 3: Virtual Machine

Use VirtualBox/VMware with CentOS 7 or Ubuntu.

### Prerequisites

Before starting, you need to:

1. **Configure Database**:
   - Edit `work/etc/game.conf`
   - Update MySQL credentials:
     ```lua
     mysqlip = "127.0.0.1"  -- or your MySQL server IP
     mysqlport = 3306
     mysqldb = "ig"
     mysqluser = "rok"
     mysqlpwd = "Kbsq123!"
     ```

2. **Setup MySQL Database**:
   - Import schema from `work/tool/sql/oc.sql`

3. **Start Redis** (if not in Docker):
   ```bash
   bash etc/start_redis.sh
   ```

4. **Configure Ports**:
   - Ensure ports 44445, 57000-57011, 56000-56011 are available
   - Windows Firewall may block these ports

### Quick Start Script (Docker)

Create a startup script:

```powershell
# start_all.ps1
docker-compose up -d
Start-Sleep -Seconds 5
docker exec -it docker_server-rok_dev-1 bash -c "cd /root/rok-server && bash etc/start_monitor.sh && sleep 2 && bash etc/start_db.sh && sleep 2 && bash etc/start_center.sh && sleep 2 && bash etc/start_login.sh && sleep 2 && bash etc/start_game.sh && sleep 2 && bash etc/start_battle.sh && sleep 2 && bash etc/start_chat.sh && sleep 2 && bash etc/start_push.sh && sleep 2 && bash etc/start_log.sh"
```

### Verifying Server Status

1. **Check logs**:
   ```bash
   tail -f work/logs/game1.Error.*.log
   ```

2. **Check ok.txt**:
   ```bash
   cat work/ok.txt
   ```
   Should show timestamps for each started server

3. **Monitor Web Interface**:
   - Open browser: `http://127.0.0.1:58000` (monitor server)

4. **Debug Console** (telnet):
   ```powershell
   telnet 127.0.0.1 56005  # Game server debug port
   ```

### Common Issues on Windows

1. **Port conflicts**: Use `netstat -ano | findstr :44445` to check
2. **Docker not running**: Ensure Docker Desktop is started
3. **Permission errors**: Run PowerShell as Administrator
4. **Line endings**: Scripts use LF, Windows uses CRLF (WSL/Docker handles this)

---

## 5. Server Status Check

### Current Status Indicators

- **Logs directory**: `work/logs/` contains error logs
- **PID files**: `work/logs/redis_*.pid` show Redis instances
- **ok.txt**: Contains startup timestamps
- **Cluster files**: `work/etc/cluster_*.lua` define server connections

### Health Check Commands

```bash
# Check if servers are running (inside container/WSL)
ps aux | grep co

# Check ports
netstat -tulpn | grep -E '57000|57005|44445'

# Check Redis
redis-cli -p 56379 ping

# Check MySQL connection
mysql -h 127.0.0.1 -u rok -p
```

---

## 6. For the Reskin Project

### What You Need to Know

1. **Server Protocol**: Uses Sproto (binary protocol)
   - Protocol files: `work/common/protocol/*.sproto`
   - Client must match these protocols

2. **Server Logic**: All game logic is in Lua
   - Game server: `work/server/game_server/`
   - Common logic: `work/common/service/`
   - You may need to adjust server logic if gameplay changes

3. **Asset References**: Server may reference asset IDs
   - Config files: `work/common/config/gen/Configs.data`
   - These IDs must match client assets

4. **Testing**: You'll need to:
   - Run server locally
   - Connect Unity client
   - Test all game features
   - Verify asset replacements work

### Next Steps

1. ✅ Set up server locally (using Docker/WSL)
2. ✅ Verify server starts and runs
3. ✅ Connect Unity client to server
4. ✅ Map current assets to new assets
5. ✅ Plan reskin implementation
6. ✅ Test each game system after reskin

---

## Summary

This is a **production-ready multiplayer game server** using:
- Skynet framework (Lua-based)
- Multi-server architecture
- MySQL + Redis backend
- Real-time battle system
- Guild/alliance features

**To run on Windows 11**: Use Docker or WSL2 (Linux environment required)

**For reskin project**: Server handles game logic; client (Unity) handles visuals. You'll need both working together to test the reskin.


