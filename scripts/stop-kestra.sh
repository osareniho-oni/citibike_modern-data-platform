#!/bin/bash

# Stop Kestra Server Script
# Usage: ./scripts/stop-kestra.sh

echo "🛑 Stopping Kestra server..."
echo ""

# Find Kestra process
KESTRA_PID=$(ps aux | grep "kestra server standalone" | grep -v grep | awk '{print $2}')

if [ -z "$KESTRA_PID" ]; then
    echo "✅ Kestra is not running"
    exit 0
fi

echo "📍 Found Kestra process: PID $KESTRA_PID"

# Try graceful shutdown first
echo "⏳ Attempting graceful shutdown..."
kill $KESTRA_PID
sleep 5

# Check if still running
if ps -p $KESTRA_PID > /dev/null 2>&1; then
    echo "⚠️  Graceful shutdown failed, forcing stop..."
    kill -9 $KESTRA_PID
    sleep 2
fi

# Verify stopped
if ps -p $KESTRA_PID > /dev/null 2>&1; then
    echo "❌ Failed to stop Kestra (PID $KESTRA_PID still running)"
    echo "Try manually: kill -9 $KESTRA_PID"
    exit 1
else
    echo "✅ Kestra stopped successfully"
fi

# Check port is free
echo ""
echo "🔍 Checking port 8080..."
if lsof -i :8080 > /dev/null 2>&1; then
    echo "⚠️  Port 8080 still in use by another process"
    lsof -i :8080
else
    echo "✅ Port 8080 is free"
fi

echo ""
echo "🎉 Done! Kestra has been stopped."