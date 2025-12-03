#开启core,修改最大文件描述符
# Set ulimit values directly (no need to modify /etc/profile)
ulimit -c unlimited 2>/dev/null || true
ulimit -n 65535 2>/dev/null || true

# Optional: Try to set in /etc/profile if we have sudo (non-blocking)
if [ -w /etc/profile ] 2>/dev/null; then
    ulimitcount=$(grep -c "ulimit" /etc/profile 2>/dev/null || echo "0")
    if [ "$ulimitcount" -eq 0 ]; then
        echo "ulimit -c unlimited" >> /etc/profile 2>/dev/null || true
        echo "ulimit -n 65535" >> /etc/profile 2>/dev/null || true
    fi
fi