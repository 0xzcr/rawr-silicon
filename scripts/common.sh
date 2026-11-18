#!/bin/bash
# Shared paths and helpers for every Vaelos Silicon script. Source it, don't run it.
# shellcheck disable=SC2034  # the variables here are used by the scripts that source this file
#
# Vaelos drives the Wine engine, DXMT and DXVK that Whisky (github.com/frankea/Whisky) installs.
# It never modifies Whisky itself, and keeps its own state in ~/Library/Application Support/Vaelos Silicon.

WHISKY_APP="/Applications/Whisky.app"
WHISKY_CMD="$WHISKY_APP/Contents/Resources/WhiskyCmd"
WHISKY_LIBS="$HOME/Library/Application Support/com.franke.Whisky/Libraries"
WHISKY_BOTTLES="$HOME/Library/Containers/com.franke.Whisky/Bottles"

WINE="$WHISKY_LIBS/Wine/bin/wine"
WINESERVER="$WHISKY_LIBS/Wine/bin/wineserver"
DXMT_DLLS="$WHISKY_LIBS/DXMT/x64"
DXVK_DLLS="$WHISKY_LIBS/DXVK/x64"

BOTTLE_NAME="Vaelos"
STATE_DIR="$HOME/Library/Application Support/Vaelos Silicon"
LOGS="$STATE_DIR/logs"
SHADER_CACHE="$STATE_DIR/shader-cache"

STEAM_EXE='C:\Program Files (x86)\Steam\steam.exe'

# Progress line for the app ("STEP Installing Steam").
step() {
  echo "STEP $*"
}

# Error line for the app, then stop.
fail() {
  echo "ERROR $*"
  exit 1
}

# Prints the folder of the Whisky bottle named $BOTTLE_NAME; returns 1 if there is none.
# shortcut: only looks in Whisky's default bottle folder; read Whisky's bottle list if custom locations matter.
find_bottle() {
  local metadata
  for metadata in "$WHISKY_BOTTLES"/*/Metadata.plist; do
    [ -f "$metadata" ] || continue
    if [ "$(plutil -extract info.name raw -o - "$metadata" 2>/dev/null)" = "$BOTTLE_NAME" ]; then
      dirname "$metadata"
      return 0
    fi
  done
  return 1
}

# Points Wine at our bottle. Every script that runs Wine calls this first.
use_bottle() {
  BOTTLE="$(find_bottle)" || fail "No Whisky bottle named $BOTTLE_NAME yet: run Setup first"
  export WINEPREFIX="$BOTTLE"
  export WINEDEBUG=-all
  # Every Wine process in a bottle must agree on the sync mode, or new ones refuse to start.
  export WINEMSYNC=1
}
