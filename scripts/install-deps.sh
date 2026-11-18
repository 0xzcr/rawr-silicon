#!/bin/bash
# Installs everything Vaelos needs that isn't on a fresh Mac: Rosetta 2, Whisky, and Whisky's Wine engine.
# Safe to run again: anything already installed is skipped. Prints "STEP ..." lines that the app shows.
#
# Downloads are pinned to versions tested with Vaelos. Their SHA-256 hashes live in this file, which is
# sealed inside the app's code signature, so a swapped or corrupted download is refused.
set -euo pipefail
source "$(dirname "$0")/common.sh"

# Whisky 3.10.2 (github.com/frankea/Whisky), signed by its developer's Apple Developer ID.
WHISKY_DMG_URL="https://github.com/frankea/Whisky/releases/download/app-v3.10.2/Whisky-3.10.2.dmg"
WHISKY_DMG_SHA256="8171d4972605d065851d4297a6bda31a65ef20dc5fe8291ef17b1bf3c30cf567"
WHISKY_DMG_MB=13
WHISKY_TEAM_ID="Z7JS58F8U3"

# Whisky's Wine engine v4.8.3: Wine 11.19, DXMT 0.80, DXVK 1.10.3.
ENGINE_URL="https://github.com/frankea/Whisky/releases/download/v4.8.3/Libraries.tar.gz"
ENGINE_SHA256="08ffabd7b7c352470faee2b1d51061b341316e401439ca805c5302acc2fb8818"
ENGINE_MB=457

WORK_DIR="$(mktemp -d)"
MOUNT_POINT=""
cleanup() {
  if [ -n "$MOUNT_POINT" ]; then hdiutil detach -quiet -force "$MOUNT_POINT" || true; fi
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

# 1. Rosetta 2 runs the x86_64 Wine engine. Installing it is the one step that needs an administrator,
#    so macOS shows its own password prompt; Vaelos never sees the password.
if ! has_rosetta; then
  step "Installing Rosetta 2 (macOS will ask for your password)"
  osascript -e 'do shell script "/usr/sbin/softwareupdate --install-rosetta --agree-to-license" with administrator privileges' >/dev/null \
    || fail "Rosetta 2 is needed to run Windows games. Install it from System Settings, or run: softwareupdate --install-rosetta"
  has_rosetta || fail "Rosetta 2 did not install"
fi

# 2. Whisky: download, check the hash, check Apple's signature names Whisky's developer, then copy it in.
if [ -z "$WHISKY_APP" ]; then
  DMG="$WORK_DIR/Whisky.dmg"
  download "$WHISKY_DMG_URL" "$DMG" "$WHISKY_DMG_SHA256" "Downloading Whisky" "$WHISKY_DMG_MB"

  step "Checking Whisky's signature"
  MOUNT_POINT="$WORK_DIR/mount"
  mkdir -p "$MOUNT_POINT"
  hdiutil attach -quiet -nobrowse -readonly -noautoopen -mountpoint "$MOUNT_POINT" "$DMG" || fail "Couldn't open the Whisky download"
  [ -d "$MOUNT_POINT/Whisky.app" ] || fail "The Whisky download doesn't contain Whisky.app"
  signed_by_team "$MOUNT_POINT/Whisky.app" "$WHISKY_TEAM_ID" || fail "Whisky's signature didn't check out, so it wasn't installed"

  step "Installing Whisky"
  # /Applications is writable for admin users; everyone else gets ~/Applications. No password either way.
  DESTINATION="$APPLICATIONS_DIR"
  [ -w "$DESTINATION" ] || DESTINATION="$HOME/Applications"
  mkdir -p "$DESTINATION"
  ditto "$MOUNT_POINT/Whisky.app" "$DESTINATION/Whisky.app"
  hdiutil detach -quiet "$MOUNT_POINT"
  MOUNT_POINT=""
fi

# 3. The Wine engine, unpacked where Whisky keeps it so Whisky sees it as installed too.
if [ ! -x "$WINE" ]; then
  ARCHIVE="$WORK_DIR/Libraries.tar.gz"
  download "$ENGINE_URL" "$ARCHIVE" "$ENGINE_SHA256" "Downloading the Wine engine" "$ENGINE_MB"

  step "Unpacking the Wine engine"
  WHISKY_SUPPORT="$(dirname "$WHISKY_LIBS")"
  mkdir -p "$WHISKY_SUPPORT"
  # Unpack beside the final location, then move it in one step, so a failure never leaves half an engine.
  UNPACK_DIR="$(mktemp -d "$WHISKY_SUPPORT/.vaelos-unpack.XXXXXX")"
  tar -xzf "$ARCHIVE" -C "$UNPACK_DIR" || { rm -rf "$UNPACK_DIR"; fail "Couldn't unpack the Wine engine (is the disk full?)"; }
  # A Libraries folder without a working wine is broken; keep it aside rather than deleting it.
  if [ -e "$WHISKY_LIBS" ]; then mv "$WHISKY_LIBS" "$WHISKY_LIBS.broken-$(date +%Y%m%d%H%M%S)"; fi
  mv "$UNPACK_DIR/Libraries" "$WHISKY_LIBS"
  rm -rf "$UNPACK_DIR"
  [ -x "$WINE" ] || fail "The Wine engine is incomplete"
fi

step "Dependencies ready"
