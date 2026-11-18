#!/bin/bash
# Prints exactly one word: how far this Mac is from being able to play.
#   no-whisky  Whisky.app is not installed
#   no-engine  Whisky is installed but hasn't downloaded its Wine engine yet
#   no-bottle  our Windows environment doesn't exist yet
#   no-steam   the environment exists but Steam isn't installed in it
#   ready      Play will work
source "$(dirname "$0")/common.sh"

if [ ! -x "$WHISKY_CMD" ]; then
  echo no-whisky
elif [ ! -x "$WINE" ]; then
  echo no-engine
elif ! BOTTLE="$(find_bottle)"; then
  echo no-bottle
elif [ ! -f "$BOTTLE/drive_c/Program Files (x86)/Steam/steam.exe" ]; then
  echo no-steam
else
  echo ready
fi
