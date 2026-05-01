#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
#                    ESP32 Upload Script
# ═══════════════════════════════════════════════════════════════════

set -e

export PATH="$HOME/bin:$PATH"

SKETCH_DIR="$(dirname "$0")/esp32_billing"
# SKETCH_DIR="$(dirname "$0")/test_panel"
# SKETCH_DIR="$(dirname "$0")/test_relay"
FQBN="esp32:esp32:esp32"

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║              ESP32 UPLOAD - Cursor Edition                 ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Check arduino-cli
if ! command -v arduino-cli &> /dev/null; then
    echo "❌ arduino-cli not found!"
    exit 1
fi

# Detect port
echo "🔍 Detecting ESP32..."
PORT=$(arduino-cli board list | grep -i "esp32\|CP210\|CH340\|USB" | head -1 | awk '{print $1}')

if [ -z "$PORT" ]; then
    echo "❌ ESP32 not found!"
    echo ""
    echo "Available ports:"
    arduino-cli board list
    echo ""
    echo "Make sure ESP32 is connected via USB"
    exit 1
fi

echo "📦 Sketch: $SKETCH_DIR"
echo "🔧 Board:  $FQBN"
echo "🔌 Port:   $PORT"
echo ""

# Compile first
echo "🔨 Compiling..."
arduino-cli compile --fqbn $FQBN "$SKETCH_DIR" --warnings none

echo ""
echo "📤 Uploading to $PORT..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

arduino-cli upload -p $PORT --fqbn $FQBN "$SKETCH_DIR"

echo ""
echo "✅ UPLOAD SUCCESS!"
echo ""
echo "📺 To monitor serial output, run:"
echo "   ./monitor.sh"
echo ""
