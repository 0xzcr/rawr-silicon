#!/bin/bash
# Close CS2, then Steam, gracefully (Steam saves its login, DXMT flushes its shader cache).
set -uo pipefail
source "$(dirname "$0")/common.sh"
use_bottle

"$WINE" taskkill /IM cs2.exe >/dev/null 2>&1
"$WINE" "$STEAM_EXE" -shutdown >/dev/null 2>&1

# Wait for everything in the bottle to exit, but never hang: force-stop after 30 seconds.
( sleep 30 && "$WINESERVER" -k ) &
WATCHDOG=$!
"$WINESERVER" -w
kill "$WATCHDOG" 2>/dev/null
exit 0
