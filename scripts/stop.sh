#!/bin/bash
# Close CS2, then Steam, gracefully (Steam saves its login, DXMT flushes its shader cache),
# then end everything else still running in our bottle.
set -uo pipefail
source "$(dirname "$0")/common.sh"
use_bottle

# True while Steam itself or CS2 is running from our bottle (helpers like steamwebhelper.exe don't count).
main_programs_running() {
  local pids
  pids="$(pids_inside "$BOTTLE" | paste -sd , -)"
  [ -n "$pids" ] && ps -o command= -p "$pids" 2>/dev/null | grep -qE '\\steam\.exe|\\cs2\.exe'
}

# 1. Ask nicely, but only if they're running: `steam -shutdown` would otherwise start Steam first.
if main_programs_running; then
  "$WINE" taskkill /IM cs2.exe >/dev/null 2>&1
  "$WINE" "$STEAM_EXE" -shutdown >/dev/null 2>&1
  for _ in $(seq 1 20); do
    main_programs_running || break
    sleep 1
  done
fi

# 2. Steam's browser and Wine's helpers often don't exit on their own: end them through Wine.
"$WINESERVER" -k 2>/dev/null

# 3. Anything that outlived the wineserver (it can no longer reach those), so Steam doesn't stay in the Dock.
#    Politely, then for good after 3 seconds.
LEFTOVERS="$(pids_inside "$BOTTLE")"
if [ -n "$LEFTOVERS" ]; then
  # shellcheck disable=SC2086  # one PID per word
  kill $LEFTOVERS 2>/dev/null
  sleep 3
  LEFTOVERS="$(pids_inside "$BOTTLE")"
  # shellcheck disable=SC2086
  [ -z "$LEFTOVERS" ] || kill -9 $LEFTOVERS 2>/dev/null
fi
exit 0
