#!/bin/bash
# Start Steam and CS2 in our bottle. Usage: launch.sh [extra CS2 options, e.g. -fullscreen -w 3024 -h 1964]
#   RETINA=1  render at the display's real pixel size (Sharp preset)
#   HUD=1     Metal performance overlay; frame times also go to logs/wine.log
#   METALFX=1 MetalFX upscaling of the final frame (measured: more stutter, so off by default)
#   TEST=1    adds -insecure (VAC off) for automated bot tests; never used by the app
set -euo pipefail
source "$(dirname "$0")/common.sh"
use_bottle
mkdir -p "$LOGS" "$SHADER_CACHE"

STEAM_DIR="$BOTTLE/drive_c/Program Files (x86)/Steam"
CS2_BIN="$STEAM_DIR/steamapps/common/Counter-Strike Global Offensive/game/bin/win64"

# --- Steam's window -----------------------------------------------------------------------------
# Steam's UI is a Chromium browser (steamwebhelper.exe). It only draws through DXVK (D3D11 -> Vulkan -> Metal):
# on Wine's own d3d11 it fails with "Skia shader compilation error" and the window stays black.
for dll in d3d11 d3d10core; do
  cp -f "$DXVK_DLLS/$dll.dll" "$BOTTLE/drive_c/windows/system32/"
  "$WINE" reg add 'HKCU\Software\Wine\AppDefaults\steamwebhelper.exe\DllOverrides' /v "$dll" /d native,builtin /f >/dev/null 2>&1
done
export DXVK_ASYNC=1                  # compile DXVK shaders in the background
export CEF_DISABLE_SANDBOX=1         # Chromium's sandbox can't work under Wine
export STEAM_DISABLE_CEF_SANDBOX=1

# --- First run: CS2 not downloaded yet ----------------------------------------------------------
# Open Steam's install dialog instead of launching, so the first real launch already gets DXMT below.
if [ ! -f "$CS2_BIN/cs2.exe" ]; then
  echo "NOTICE CS2 isn't installed yet. Steam will download it (about 60 GB); press Play again when it's done."
  exec "$WINE" "$STEAM_EXE" "steam://install/730" > "$LOGS/wine.log" 2>&1
fi

# --- CS2's graphics: DXMT (D3D11 -> Metal), for cs2.exe only ------------------------------------
# The DLLs sit next to cs2.exe and a per-app override prefers them, so nothing else in the bottle uses DXMT.
# Copied every launch because a CS2 update or Steam file check can remove them.
for dll in d3d11 dxgi d3d10core; do
  cp -f "$DXMT_DLLS/$dll.dll" "$CS2_BIN/"
  "$WINE" reg add 'HKCU\Software\Wine\AppDefaults\cs2.exe\DllOverrides' /v "$dll" /d native,builtin /f >/dev/null 2>&1
done

# Retina off: Wine reports the display's scaled size (1512x982 on a 14" MacBook Pro). On: its real pixels.
RETINA_MODE=n
[ "${RETINA:-0}" = 1 ] && RETINA_MODE=y
"$WINE" reg add 'HKCU\Software\Wine\Mac Driver' /v RetinaMode /d "$RETINA_MODE" /f >/dev/null 2>&1

# Persistent shader cache: the measured difference between 16 freezes a minute (cold) and 1 (warm).
export DXMT_SHADER_CACHE=1
export DXMT_SHADER_CACHE_PATH="$SHADER_CACHE"
export DXMT_METALFX_SPATIAL_SWAPCHAIN="${METALFX:-0}"
export MTL_HUD_ENABLED="${HUD:-0}"
export MTL_HUD_LOG_ENABLED="${HUD:-0}"

# -condebug keeps CS2's console.log for crash diagnosis; it doesn't affect VAC.
TEST_OPTIONS=()
[ "${TEST:-0}" = 1 ] && TEST_OPTIONS=(-insecure)

# ${array[@]+...}: macOS's bash 3.2 treats an empty array as unbound under set -u.
exec "$WINE" "$STEAM_EXE" -applaunch 730 -novid -console -condebug \
  ${TEST_OPTIONS[@]+"${TEST_OPTIONS[@]}"} "$@" > "$LOGS/wine.log" 2>&1
