#!/bin/bash
# One-time setup: a Whisky bottle named "Vaelos" with Windows Steam installed in it.
# Safe to run again: every finished step is skipped. Prints "STEP ..." lines that the app shows.
set -euo pipefail
source "$(dirname "$0")/common.sh"

STEAM_INSTALLER_URL="https://cdn.cloudflare.steamstatic.com/client/installer/SteamSetup.exe"

[ -x "$WHISKY_CMD" ] || fail "Whisky is not installed"
[ -x "$WINE" ] || fail "Whisky's Wine engine is missing: open Whisky once so it can download it"

# 1. The bottle (a self-contained Windows environment), created through Whisky so Whisky can manage it too.
if ! find_bottle >/dev/null; then
  step "Creating the Windows environment"
  "$WHISKY_CMD" create "$BOTTLE_NAME" >/dev/null
fi
use_bottle

# 2. Windows' system files inside the bottle.
if [ ! -f "$BOTTLE/drive_c/windows/system32/kernel32.dll" ]; then
  step "Preparing Windows (about a minute)"
  "$WINE" wineboot --init >/dev/null 2>&1
  "$WINESERVER" -w
fi

# 3. Steam, straight from Valve's CDN.
if [ ! -f "$BOTTLE/drive_c/Program Files (x86)/Steam/steam.exe" ]; then
  step "Downloading Steam from Valve"
  DOWNLOAD_DIR="$(mktemp -d)"
  INSTALLER="$DOWNLOAD_DIR/SteamSetup.exe"
  # HTTPS only (no downgrade on redirect), TLS 1.2+, fail on HTTP errors instead of saving an error page.
  curl --fail --location --proto '=https' --proto-redir '=https' --tlsv1.2 --silent --show-error \
    --output "$INSTALLER" "$STEAM_INSTALLER_URL"
  # shortcut: checks it is a Windows executable, not Valve's Authenticode signature; add osslsigncode to verify that.
  [ "$(head -c 2 "$INSTALLER")" = "MZ" ] || fail "Steam download is not a Windows program"

  step "Installing Steam"
  "$WINE" "$INSTALLER" /S >/dev/null 2>&1
  "$WINESERVER" -w
  rm -rf "$DOWNLOAD_DIR"
fi

[ -f "$BOTTLE/drive_c/Program Files (x86)/Steam/steam.exe" ] || fail "Steam did not install"
step "Done"
