#!/usr/bin/env bash
set -euo pipefail

# Launch a Wine game with automatic GPU detection.
# Usage: ./run.sh <name> "/path/to/game.exe"

NAME="${1:?Usage: run.sh <name> \"/path/to/game.exe\"}"
EXE_PATH="$(realpath "${2:?Usage: run.sh <name> \"/path/to/game.exe\"}")"
PREFIX="$HOME/.local/share/wine-$NAME"

command -v wine >/dev/null || { echo "Install wine first"; exit 1; }
[[ -d "$PREFIX" ]] || { echo "Prefix not found: $PREFIX — run setup.sh $NAME first"; exit 1; }
[[ -f "$EXE_PATH" ]] || { echo "Exe not found: $EXE_PATH"; exit 1; }

# GPU detection: NVIDIA uses XWayland + GLX, otherwise native Wayland
GPU_ENV=()
if command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null; then
  : "${DISPLAY:=${GNOME_SETUP_DISPLAY:-:1}}"
  GPU_ENV=(DISPLAY="$DISPLAY" __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia)
else
  unset DISPLAY 2>/dev/null || true
  GPU_ENV=(WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}")
fi

wineserver -k 2>/dev/null || true

cd "$(dirname "$EXE_PATH")"
exec env \
  "${GPU_ENV[@]}" \
  WINEPREFIX="$PREFIX" \
  XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" \
  WINEDEBUG=-all \
  wine "./$(basename "$EXE_PATH")" 2>/tmp/wine-$NAME.log
