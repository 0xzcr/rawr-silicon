#!/bin/bash
# Benchmark: Dust2 with 10 bots, spectated, then fps for a 60 s window starting 10 s after the bots join.
# Usage: tools/bench.sh [extra CS2 options]      Results: tools/fps.py output (avg, 1%/0.1% lows, hitches).
# Runs CS2 with -insecure (VAC off) so automated testing never touches matchmaking.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/common.sh
use_bottle

GAME="$BOTTLE/drive_c/Program Files (x86)/Steam/steamapps/common/Counter-Strike Global Offensive/game/csgo"
CONSOLE="$GAME/console.log"

# The bot match config: offline Dust2, 10 bots, we join spectators so the camera follows live play.
cat > "$GAME/cfg/vaelos_bench.cfg" <<'CFG'
sv_cheats 1
mp_autoteambalance 0
mp_limitteams 0
bot_quota 10
bot_quota_mode normal
mp_warmup_end
mp_roundtime 5
mp_freezetime 0
fps_max 0
jointeam 1
CFG

HUD=1 TEST=1 scripts/launch.sh "$@" +map de_dust2 +exec vaelos_bench &

# CS2 wipes console.log on every launch, so once cs2.exe is up the whole file belongs to this run.
until pgrep -f 'win64.cs2\.exe' >/dev/null && grep -q "OnPreResetRound" "$CONSOLE" 2>/dev/null; do
  sleep 2
done
echo "bots playing, sampling..."
sleep 70
python3 tools/fps.py 60
