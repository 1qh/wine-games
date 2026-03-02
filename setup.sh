#!/usr/bin/env bash
set -euo pipefail

# Setup a Wine prefix with core fonts.
# Usage: ./setup.sh <name> [--clean]
# Prefix: ~/.local/share/wine-<name>

NAME="${1:?Usage: setup.sh <name> [--clean]}"
PREFIX="$HOME/.local/share/wine-$NAME"

for arg in "$@"; do
  if [[ "$arg" == "--clean" ]]; then
    wineserver -k 2>/dev/null || true
    rm -rf "$PREFIX"
  fi
done

command -v wine >/dev/null || { echo "Install wine first"; exit 1; }
command -v winetricks >/dev/null || { echo "Install winetricks first"; exit 1; }

if [[ -f "$PREFIX/system.reg" ]]; then
  echo "Prefix exists: $PREFIX (use --clean to recreate)"
  exit 0
fi

echo "Creating prefix: $PREFIX"
WINEPREFIX="$PREFIX" WINEARCH=win64 wineboot --init 2>/dev/null
wineserver -w 2>/dev/null || true

echo "Installing core fonts..."
WINEPREFIX="$PREFIX" winetricks -q corefonts 2>/dev/null
wineserver -w 2>/dev/null || true

echo "Done: $PREFIX"
