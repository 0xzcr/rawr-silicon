#!/bin/bash
# Shared paths and helpers for every Vaelos Silicon script. Source it, don't run it.
# shellcheck disable=SC2034  # the variables here are used by the scripts that source this file
#
# Vaelos drives the Wine engine, DXMT and DXVK that Whisky (github.com/frankea/Whisky) installs.
# It installs Whisky if needed but never modifies it, and keeps its own state in
# ~/Library/Application Support/Vaelos Silicon.

# Where apps are installed. Tests point this at a scratch folder.
APPLICATIONS_DIR="${VAELOS_APPLICATIONS:-/Applications}"

# Whisky.app in /Applications or ~/Applications; empty if it isn't installed.
WHISKY_APP=""
for candidate in "$APPLICATIONS_DIR/Whisky.app" "$HOME/Applications/Whisky.app"; do
  if [ -x "$candidate/Contents/Resources/WhiskyCmd" ]; then WHISKY_APP="$candidate"; break; fi
done
WHISKY_CMD="${WHISKY_APP:+$WHISKY_APP/Contents/Resources/WhiskyCmd}"
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

# Rosetta 2 is installed if an Intel binary can run.
has_rosetta() {
  /usr/bin/arch -x86_64 /usr/bin/true 2>/dev/null
}

# Downloads over HTTPS only and refuses the file unless its SHA-256 matches.
# Prints "STEP <label> (N of TOTAL MB)" every two seconds while it runs.
#   download <url> <output file> <sha256> <label> <expected MB>
download() {
  local url="$1" output="$2" expected_sha256="$3" label="$4" total_mb="$5"
  step "$label"
  # No downgrade to plain HTTP on redirect, TLS 1.2+, and an HTTP error fails instead of saving an error page.
  # A connection that stalls (under 1 KB/s for a minute) fails instead of hanging Setup forever.
  curl --fail --location --proto '=https' --proto-redir '=https' --tlsv1.2 --silent --show-error \
    --retry 3 --connect-timeout 20 --speed-limit 1024 --speed-time 60 \
    --output "$output" "$url" &
  local curl_pid=$! bytes
  while kill -0 "$curl_pid" 2>/dev/null; do
    sleep 2
    bytes="$(stat -f %z "$output" 2>/dev/null || echo 0)"
    step "$label ($((bytes / 1048576)) of $total_mb MB)"
  done
  wait "$curl_pid" || fail "$label failed: check your internet connection and try again"

  local actual_sha256
  actual_sha256="$(shasum -a 256 "$output" | cut -d ' ' -f 1)"
  [ "$actual_sha256" = "$expected_sha256" ] || fail "$label: the file doesn't match its published checksum, so it wasn't used"
}

# True if an app is intact and signed with an Apple-issued certificate belonging to this developer team.
#   signed_by_team <app> <team id>
signed_by_team() {
  codesign --verify --deep --strict \
    -R="anchor apple generic and certificate leaf[subject.OU] = \"$2\"" "$1" 2>/dev/null
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

# Prints the PIDs of processes running from inside a folder (their working directory is in it).
# Catches Wine processes that outlived their wineserver, which `wineserver -k` can no longer reach,
# without touching other Wine setups such as other apps' prefixes.
#   pids_inside <folder>
pids_inside() {
  # lsof reports resolved paths (/private/var, not /var), so compare against the resolved folder.
  local folder
  folder="$(cd "$1" && pwd -P)" || return 0
  lsof -d cwd -Fpn 2>/dev/null | awk -v folder="$folder/" '
    /^p/ { pid = substr($0, 2) }
    /^n/ { if (index(substr($0, 2) "/", folder) == 1) print pid }'
}

# Points Wine at our bottle. Every script that runs Wine calls this first.
use_bottle() {
  BOTTLE="$(find_bottle)" || fail "No Whisky bottle named $BOTTLE_NAME yet: run Setup first"
  export WINEPREFIX="$BOTTLE"
  export WINEDEBUG=-all
  # Every Wine process in a bottle must agree on the sync mode, or new ones refuse to start.
  export WINEMSYNC=1
}
