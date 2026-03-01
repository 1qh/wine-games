#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# ShootersPool Online — Launch (Wine 11 + Native Wayland)
#
# Launches the game fullscreen without decorations using Wine's native
# Wayland driver. The DISPLAY env var is deliberately unset to force
# Wine to use winewayland.so instead of XWayland — this avoids the
# IncorrectSoundFormat crash that occurs under X11.
#
# Usage: ./run.sh
# =============================================================================

# --- Constants ----------------------------------------------------------------
PREFIX="$HOME/.local/share/shooterspool"
WINE="/opt/wine-stable/bin/wine"
WINESERVER="/opt/wine-stable/bin/wineserver"
GAME_EXE="$PREFIX/drive_c/Program Files (x86)/ShootersPool/bin/ShootersPool Online.exe"

# --- Validate -----------------------------------------------------------------
[[ -x "$WINE" ]]    || { echo "ERROR: Wine not found at $WINE — run install.sh first"; exit 1; }
[[ -d "$PREFIX" ]]   || { echo "ERROR: Prefix not found at $PREFIX — run install.sh first"; exit 1; }
[[ -f "$GAME_EXE" ]] || {
    # Try alternate location
    ALT="$PREFIX/drive_c/Program Files/ShootersPool/bin/ShootersPool Online.exe"
    [[ -f "$ALT" ]] && GAME_EXE="$ALT" || { echo "ERROR: Game exe not found — run install.sh first"; exit 1; }
}

# --- Cleanup any previous instances -------------------------------------------
echo "Cleaning up previous instances..."
"$WINESERVER" -k 2>/dev/null || true
kill -9 $(ps aux | grep -i "wine\|shooters\|wineserver\|winedevice\|CrUtility\|Graphics" | grep -v grep | awk '{print $2}') 2>/dev/null || true
sleep 2

REMAINING=$(ps aux | grep -i "wine\|shooters\|wineserver\|winedevice\|CrUtility\|Graphics" | grep -v grep | wc -l)
if [[ "$REMAINING" -gt 0 ]]; then
    echo "  WARNING: $REMAINING processes still running, force killing..."
    kill -9 $(ps aux | grep -i "wine\|shooters\|wineserver\|winedevice\|CrUtility\|Graphics" | grep -v grep | awk '{print $2}') 2>/dev/null || true
    sleep 2
fi
echo "  Clean"

# --- Launch -------------------------------------------------------------------
echo "Launching ShootersPool Online (Wine Wayland, fullscreen)..."
echo "  Prefix: $PREFIX"
echo "  Exe: $GAME_EXE"

exec env -u DISPLAY \
    WINEPREFIX="$PREFIX" \
    WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}" \
    XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" \
    "$WINE" "$GAME_EXE"
