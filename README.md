Run Windows games on Linux with Wine.

## Usage

```bash
# 1. Create a Wine prefix (once per game)
./setup.sh my-game

# 2. Install the game into the prefix
WINEPREFIX=~/.local/share/wine-my-game wine /path/to/installer.exe

# 3. Launch
./run.sh my-game "$HOME/.local/share/wine-my-game/drive_c/.../Game.exe"
```

## Scripts

### `setup.sh <name> [--clean]`

Creates a 64-bit Wine prefix at `~/.local/share/wine-<name>` with Windows core fonts.

### `run.sh <name> "/path/to/game.exe"`

Launches a game from a Wine prefix. Automatically detects GPU:

- **NVIDIA** — XWayland + GLX PRIME offload
- **Intel/AMD** — native Wayland

Launches from the exe's parent directory (some games use relative paths for assets).

## Requirements

- `wine`
- `winetricks`

## Notes

- On hybrid GPU laptops, NVIDIA games run through XWayland. Intel/AMD games use native Wayland.
- Wine-GE and Proton-GE may break OpenGL games that use CEGUIOpenGLRenderer. Vanilla Wine works.
- Pass `--clean` to `setup.sh` to wipe and recreate a prefix.
