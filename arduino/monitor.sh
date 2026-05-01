#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
#                    ESP32 Serial Monitor
# ═══════════════════════════════════════════════════════════════════

export PATH="$HOME/bin:$PATH"

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║              ESP32 SERIAL MONITOR                          ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Detect port
PORT=$(arduino-cli board list 2>/dev/null | grep -i "esp32\|CP210\|CH340\|USB" | head -1 | awk '{print $1}')

if [ -z "$PORT" ]; then
    # Fallback to common ports
    if [ -e /dev/ttyUSB0 ]; then
        PORT="/dev/ttyUSB0"
    elif [ -e /dev/ttyACM0 ]; then
        PORT="/dev/ttyACM0"
    else
        echo "❌ ESP32 not found!"
        echo ""
        echo "Available ports:"
        ls -la /dev/tty* 2>/dev/null | grep -E "USB|ACM" || echo "None found"
        exit 1
    fi
fi

echo "🔌 Port: $PORT"
echo "📊 Baud: 115200"
echo ""
echo "Press Ctrl+C to exit"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Use arduino-cli monitor or fallback to screen
if command -v arduino-cli &> /dev/null; then
    arduino-cli monitor -p $PORT -c baudrate=115200
else
    # Fallback to cat or screen
    stty -F $PORT 115200 cs8 -cstopb -parenb
    cat $PORT
fi
