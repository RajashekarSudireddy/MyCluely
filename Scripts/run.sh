#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$DIR/build/MyCluely.app"

if [ ! -d "$APP_DIR" ]; then
    echo "App bundle not found. Building first..."
    bash "$DIR/Scripts/build.sh"
fi

echo "🚀 Launching MyCluely..."
open "$APP_DIR"

echo "✨ MyCluely is running!"
echo "   - Look for the floating HUD on the top right of your screen."
echo "   - Also accessible from your macOS Menu Bar (ear & waveform icon)."
echo "   - Shortcuts:"
echo "       • Cmd + Shift + P: Pause / Resume Hearing"
echo "       • Cmd + Shift + H: Show / Hide Floating HUD"
echo "   - Audio Source: Microphone (Default) active."
