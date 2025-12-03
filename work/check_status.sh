#!/bin/bash
# Quick status check for game servers
# Run from work directory

echo "=========================================="
echo "Game Server Status Check"
echo "=========================================="
echo ""

# Check running processes
PROCESS_COUNT=$(ps aux | grep "\./co" | grep -v grep | wc -l)
echo "Running server processes: $PROCESS_COUNT / 9"
if [ "$PROCESS_COUNT" -eq 9 ]; then
    echo "✅ All servers running"
elif [ "$PROCESS_COUNT" -gt 0 ]; then
    echo "⚠️  Only $PROCESS_COUNT servers running"
else
    echo "❌ No servers running"
fi
echo ""

# Check ok.txt
echo "Server startup status:"
if [ -f "ok.txt" ]; then
    cat ok.txt
else
    echo "❌ ok.txt not found - servers may not have started"
fi
echo ""

# Check ports
echo "Listening ports:"
if command -v netstat &> /dev/null; then
    netstat -tulpn 2>/dev/null | grep -E '44445|57000|57005' | head -5 || echo "No ports listening"
elif command -v ss &> /dev/null; then
    ss -tulpn 2>/dev/null | grep -E '44445|57000|57005' | head -5 || echo "No ports listening"
else
    echo "Cannot check ports (netstat/ss not available)"
fi
echo ""

# Check MySQL
echo "MySQL connection:"
if mysql -h 127.0.0.1 -u rok -pKbsq123! -e "SELECT 1;" &>/dev/null; then
    echo "✅ MySQL OK"
else
    echo "❌ MySQL connection failed"
    echo "   Check: mysql -h 127.0.0.1 -u rok -pKbsq123!"
fi
echo ""

# Check Redis
echo "Redis connection:"
if redis-cli -p 56379 ping &>/dev/null; then
    echo "✅ Redis OK"
else
    echo "❌ Redis connection failed"
    echo "   Check: redis-cli -p 56379 ping"
fi
echo ""

# Check recent errors
echo "Recent errors (last 3):"
if ls logs/*.Error.*.log &>/dev/null; then
    grep -i error logs/*.Error.*.log 2>/dev/null | tail -3 || echo "No errors found"
else
    echo "No error logs found"
fi
echo ""

# Server IP for client
echo "Server IP for Unity client:"
if command -v hostname &> /dev/null; then
    VM_IP=$(hostname -I | awk '{print $1}')
    echo "  $VM_IP:44445"
else
    echo "  (Run: ip addr show to find IP)"
fi
echo ""

echo "=========================================="

