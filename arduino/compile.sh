#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
#                    ESP32 Compile Script
# ═══════════════════════════════════════════════════════════════════

set -e

export PATH="$HOME/bin:$PATH"

SKETCH_DIR="$(dirname "$0")/esp32_billing"
FQBN="esp32:esp32:esp32"

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║              ESP32 COMPILE - Cursor Edition                ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Check arduino-cli
if ! command -v arduino-cli &> /dev/null; then
    echo "❌ arduino-cli not found!"
    echo "   Run: curl -fsSL https://raw.githubusercontent.com/arduino/arduino-cli/master/install.sh | sh"
    exit 1
fi

echo "📦 Sketch: $SKETCH_DIR"
echo "🔧 Board:  $FQBN"
echo ""

# Install ArduinoJson if not exists
echo "📚 Checking libraries..."
arduino-cli lib install ArduinoJson 2>/dev/null || true

# Compile
echo ""
echo "🔨 Compiling..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

arduino-cli compile --fqbn $FQBN "$SKETCH_DIR" --warnings none

echo ""
echo "✅ COMPILE SUCCESS!"
echo ""
