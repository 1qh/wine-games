#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# ShootersPool Online — Install (Wine 11 + Native Wayland)
#
# Usage: ./install.sh /path/to/ShootersPool-*_Setup.exe
#
# What this does:
#   1. Installs Wine 11 from WineHQ (if not present)
#   2. Installs 32-bit NVIDIA GL libraries (manual extract, no apt — safe for GDM)
#   3. Creates a 64-bit Wine prefix with native Wayland support
#   4. Installs Windows core fonts (fixes CEF dwrite crash)
#   5. Runs the ShootersPool NSIS installer silently
#   6. Configures gfx.ini for fullscreen without decorations
#
# Why Wine 11, not Proton?
#   Proton strips winewayland.so. The game crashes under XWayland with
#   IncorrectSoundFormat. Only Wine 11's native Wayland driver avoids this.
#
# Why manual 32-bit NVIDIA libs?
#   apt install libnvidia-gl-590:i386 pulls in libnvidia-egl-wayland1:i386
#   which breaks GDM. We extract just the GL libraries from the .deb instead.
# =============================================================================

INSTALLER="${1:?Usage: install.sh /path/to/ShootersPool_Setup.exe}"
INSTALLER="$(realpath "$INSTALLER")"

# --- Constants ----------------------------------------------------------------
PREFIX="$HOME/.local/share/shooterspool"
WINE="/opt/wine-stable/bin/wine"
WINESERVER="/opt/wine-stable/bin/wineserver"
GAME_REL="drive_c/Program Files (x86)/ShootersPool"
GAME_DIR="$PREFIX/$GAME_REL"
GAME_BIN="$GAME_DIR/bin"
GAME_EXE="$GAME_BIN/ShootersPool Online.exe"
NVIDIA_DRIVER_VER="590.48.01"
LIB32_DIR="/usr/lib/i386-linux-gnu"

# --- Helpers ------------------------------------------------------------------
need_sudo() { echo "  (requires sudo)"; }

cleanup_wine() {
    "$WINESERVER" -k 2>/dev/null || true
    kill -9 $(ps aux | grep -i "wine\|shooters\|wineserver\|winedevice\|CrUtility\|Graphics" | grep -v grep | awk '{print $2}') 2>/dev/null || true
    sleep 2
}

# --- Validate -----------------------------------------------------------------
echo "=== ShootersPool Installer (Wine 11 + Wayland) ==="

[[ -f "$INSTALLER" ]] || { echo "ERROR: Installer not found: $INSTALLER"; exit 1; }

# --- 1. Install Wine 11 from WineHQ ------------------------------------------
echo "[1/6] Checking Wine 11..."
if [[ -x "$WINE" ]] && "$WINE" --version 2>/dev/null | grep -q "wine-11"; then
    echo "  Wine 11 already installed: $($WINE --version)"
else
    need_sudo
    echo "  Adding WineHQ repository..."
    sudo dpkg --add-architecture i386
    sudo mkdir -pm755 /etc/apt/keyrings
    sudo wget -qO /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key
    CODENAME=$(lsb_release -cs)
    sudo wget -qNP /etc/apt/sources.list.d/ "https://dl.winehq.org/wine-builds/ubuntu/dists/${CODENAME}/winehq-${CODENAME}.sources"
    sudo apt update -qq
    echo "  Installing winehq-stable..."
    sudo apt install -y --install-recommends winehq-stable
    echo "  Wine installed: $($WINE --version)"
fi

# --- 2. Install 32-bit NVIDIA GL libraries -----------------------------------
echo "[2/6] Checking 32-bit NVIDIA GL libraries..."
if [[ -f "$LIB32_DIR/libGLX_nvidia.so.$NVIDIA_DRIVER_VER" ]]; then
    echo "  Already present"
else
    need_sudo
    echo "  Downloading libnvidia-gl-590:i386 .deb (extract only, not installed)..."
    TMPDIR=$(mktemp -d)
    trap "rm -rf $TMPDIR" EXIT

    apt download "libnvidia-gl-590:i386" 2>/dev/null || {
        # Fallback: download from archive
        DEB_URL=$(apt-cache show "libnvidia-gl-590:i386" 2>/dev/null | grep "^Filename:" | head -1 | awk '{print $2}')
        if [[ -n "$DEB_URL" ]]; then
            wget -qO "$TMPDIR/libnvidia-gl.deb" "http://archive.ubuntu.com/ubuntu/$DEB_URL"
        else
            echo "ERROR: Cannot download libnvidia-gl-590:i386"; exit 1
        fi
    }
    DEB_FILE=$(ls libnvidia-gl-590_*_i386.deb 2>/dev/null || ls "$TMPDIR"/*.deb 2>/dev/null)
    [[ -f "$DEB_FILE" ]] || { echo "ERROR: .deb download failed"; exit 1; }

    echo "  Extracting 32-bit GL libraries..."
    dpkg-deb -x "$DEB_FILE" "$TMPDIR/extract"
    rm -f "$DEB_FILE"

    # Copy libraries
    LIBS=(
        "libGLX_nvidia.so.$NVIDIA_DRIVER_VER"
        "libEGL_nvidia.so.$NVIDIA_DRIVER_VER"
        "libnvidia-glcore.so.$NVIDIA_DRIVER_VER"
        "libnvidia-tls.so.$NVIDIA_DRIVER_VER"
        "libnvidia-glsi.so.$NVIDIA_DRIVER_VER"
        "libnvidia-gpucomp.so.$NVIDIA_DRIVER_VER"
        "libnvidia-glvkspirv.so.$NVIDIA_DRIVER_VER"
        "libnvidia-eglcore.so.$NVIDIA_DRIVER_VER"
        "libGLESv2_nvidia.so.$NVIDIA_DRIVER_VER"
    )
    for lib in "${LIBS[@]}"; do
        SRC=$(find "$TMPDIR/extract" -name "$lib" 2>/dev/null | head -1)
        if [[ -f "$SRC" ]]; then
            sudo cp "$SRC" "$LIB32_DIR/$lib"
        else
            echo "  WARN: $lib not found in .deb"
        fi
    done

    # Create symlinks
    sudo ln -sf "libGLX_nvidia.so.$NVIDIA_DRIVER_VER" "$LIB32_DIR/libGLX_nvidia.so.0"
    sudo ln -sf "libEGL_nvidia.so.$NVIDIA_DRIVER_VER" "$LIB32_DIR/libEGL_nvidia.so.0"
    sudo ln -sf "libGLESv2_nvidia.so.$NVIDIA_DRIVER_VER" "$LIB32_DIR/libGLESv2_nvidia.so.2"
    sudo ldconfig

    trap - EXIT
    rm -rf "$TMPDIR"
    echo "  32-bit NVIDIA GL libraries installed"
fi

# --- 3. Create 64-bit Wine prefix --------------------------------------------
echo "[3/6] Creating 64-bit Wine prefix..."
cleanup_wine
rm -rf "$PREFIX"
env -u DISPLAY WINEPREFIX="$PREFIX" WINEARCH=win64 "$WINE" wineboot --init 2>/dev/null
"$WINESERVER" -w 2>/dev/null || true
sleep 2

# Configure Wine for native Wayland
env -u DISPLAY WINEPREFIX="$PREFIX" "$WINE" reg add \
    "HKCU\\Software\\Wine\\Drivers" /v Graphics /t REG_SZ /d wayland /f 2>/dev/null
env -u DISPLAY WINEPREFIX="$PREFIX" "$WINE" reg add \
    "HKCU\\Software\\Wine\\X11 Driver" /v Decorated /t REG_SZ /d N /f 2>/dev/null
"$WINESERVER" -w 2>/dev/null || true
echo "  Prefix created: $PREFIX (win64)"

# --- 4. Install core fonts ---------------------------------------------------
echo "[4/6] Installing Windows core fonts..."
command -v winetricks >/dev/null || {
    echo "  Installing winetricks..."
    sudo wget -qO /usr/local/bin/winetricks https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks
    sudo chmod +x /usr/local/bin/winetricks
}
env -u DISPLAY WINEPREFIX="$PREFIX" WINE="$WINE" winetricks -q corefonts 2>&1 | tail -3 || {
    echo "  WARN: winetricks corefonts failed, trying manual install..."
    FONT_DIR="$PREFIX/drive_c/windows/Fonts"
    mkdir -p "$FONT_DIR"
    for font_url in \
        "https://downloads.sourceforge.net/corefonts/arial32.exe" \
        "https://downloads.sourceforge.net/corefonts/times32.exe" \
        "https://downloads.sourceforge.net/corefonts/verdana32.exe"; do
        wget -qO /tmp/font.exe "$font_url" 2>/dev/null && \
            cabextract -q -d "$FONT_DIR" /tmp/font.exe 2>/dev/null || true
    done
    rm -f /tmp/font.exe
}
"$WINESERVER" -w 2>/dev/null || true

# --- 5. Run the NSIS installer ------------------------------------------------
echo "[5/6] Running game installer (silent, may take a few minutes)..."
env -u DISPLAY WINEPREFIX="$PREFIX" "$WINE" "$INSTALLER" /S
"$WINESERVER" -w 2>/dev/null || true
sleep 3

# Verify game installed
if [[ ! -f "$GAME_EXE" ]]; then
    ALT_DIR="$PREFIX/drive_c/Program Files/ShootersPool"
    if [[ -d "$ALT_DIR" ]]; then
        GAME_DIR="$ALT_DIR"
        GAME_BIN="$GAME_DIR/bin"
        GAME_EXE="$GAME_BIN/ShootersPool Online.exe"
    fi
fi
[[ -f "$GAME_EXE" ]] || { echo "ERROR: Game exe not found. Check: ls \"$PREFIX/drive_c/Program Files\"*/"; exit 1; }
echo "  Installed to: $GAME_DIR"

# --- 6. Configure gfx.ini for fullscreen ------------------------------------
echo "[6/6] Configuring fullscreen..."
# Detect display resolution and refresh rate
RES_X=$(xdpyinfo 2>/dev/null | grep dimensions | awk '{print $2}' | cut -dx -f1 || echo "2560")
RES_Y=$(xdpyinfo 2>/dev/null | grep dimensions | awk '{print $2}' | cut -dx -f2 || echo "1440")
REFRESH=$(xrandr 2>/dev/null | grep '\*' | head -1 | awk '{print $1}' | cut -d. -f1 || echo "165")
# Fallback: use Wayland-native detection
if [[ -z "$RES_X" || "$RES_X" == "0" ]]; then
    RES_INFO=$(wlr-randr 2>/dev/null || gnome-randr 2>/dev/null || true)
    RES_X="${RES_X:-2560}"
    RES_Y="${RES_Y:-1440}"
    REFRESH="${REFRESH:-165}"
fi

GFX_DIR="$PREFIX/drive_c/users/$(whoami)/AppData/Roaming/ShootersPool/settings"
mkdir -p "$GFX_DIR"

# Run game briefly to generate default settings, then kill
echo "  Generating default settings..."
env -u DISPLAY \
    WINEPREFIX="$PREFIX" \
    WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}" \
    XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" \
    "$WINE" "$GAME_EXE" &
sleep 10
cleanup_wine

# Write gfx.ini
GFX_INI="$GFX_DIR/gfx.ini"
cat > "$GFX_INI" << EOF
{
    "screen_res_x_full": "$RES_X",
    "screen_res_y_full": "$RES_Y",
    "screen_res_x_win": "1280",
    "screen_res_y_win": "720",
    "colordepth": "32",
    "antialiasing": "4",
    "frequency": "$REFRESH",
    "screenMode": "1",
    "vsync": "1",
    "bloom": "0",
    "ssao": "0",
    "smaa": "0",
    "blur": "0",
    "fixedDOF": "0",
    "blurQuality": "3",
    "shadows": "1",
    "disableBackground": "0",
    "HUDscale": "1.25",
    "browserScale": "0",
    "lights": "1",
    "language": "en",
    "texTable": "4",
    "texLocation": "4",
    "texBalls": "4",
    "texCues": "4",
    "crowd": "4",
    "shTable": "4",
    "shLocation": "4",
    "shBalls": "3",
    "shCues": "4",
    "gmtTable": "4",
    "gmtLocation": "4",
    "gmtBalls": "3",
    "gmtCues": "4",
    "maxLights": "10",
    "maxLightsPerObject": "4",
    "texShadows": "4",
    "texReflections": "4",
    "texAnisotropy": "4",
    "limitFPS": "10000",
    "sndBalls": "45",
    "sndTable": "100",
    "sndCue": "42",
    "sndAmbiance": "100",
    "sndCrowd": "100",
    "sndMusicInGame": "50",
    "sndMusicMenu": "50",
    "sndReferee": "100",
    "sndMenuFx": "12"
}
EOF
echo "  gfx.ini configured: ${RES_X}x${RES_Y}@${REFRESH}Hz, fullscreen, no decorations"

cleanup_wine

echo ""
echo "=== Installation complete ==="
echo "Game: $GAME_EXE"
echo "Prefix: $PREFIX"
echo "Mode: Wine 11 native Wayland, fullscreen, no decorations"
echo ""
echo "Launch with: ./run.sh"
