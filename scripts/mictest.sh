#!/bin/bash
# Record the default mic through Wine, exactly the way CS2's voice chat captures it.
# Usage: mictest.sh <micrec.exe> <seconds> <out.wav>    (the app plays the test tone and analyses the file)
set -euo pipefail
source "$(dirname "$0")/common.sh"
use_bottle

RECORDER="$1"
SECONDS_TO_RECORD="$2"
OUT_FILE="$3"

# Wine sees the Mac's file system as drive Z:.
OUT_WINDOWS_PATH="Z:${OUT_FILE//\//\\}"

rm -f "$OUT_FILE"
# -1 is WAVE_MAPPER: the system default mic, which is what a Windows game gets.
"$WINE" "$RECORDER" -1 "$SECONDS_TO_RECORD" 48000 "$OUT_WINDOWS_PATH" >/dev/null 2>&1 || true
[ -s "$OUT_FILE" ] || fail "Recording failed: allow microphone access for Vaelos Silicon in System Settings"
echo "RECORDED $OUT_FILE"
