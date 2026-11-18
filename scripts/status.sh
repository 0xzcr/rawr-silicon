#!/bin/bash
# Prints exactly one word: how far this Mac is from being able to play.
#   no-rosetta Rosetta 2 (needed for the x86_64 Wine engine) is not installed
#   no-whisky  Whisky.app is not installed
#   no-engine  Whisky is installed but its Wine engine isn't
#   no-bottle  our Windows environment doesn't exist yet
#   no-steam   the environment exists but Steam isn't installed in it
#   ready      Play will work
source "$(dirname "$0")/common.sh"

if ! has_rosetta; then
  echo no-rosetta
elif [ -z "$WHISKY_CMD" ]; then
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
