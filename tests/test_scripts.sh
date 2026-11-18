#!/bin/bash
# Checks for the shell scripts: syntax, shellcheck, and bottle discovery against a fake HOME.
set -uo pipefail
cd "$(dirname "$0")/.."
FAILURES=0

check() {
  if eval "$2"; then echo "  ok    $1"; else echo "  FAIL  $1"; FAILURES=$((FAILURES + 1)); fi
}

echo "Scripts"
check "all scripts parse" 'for f in scripts/*.sh packaging/*.sh tools/*.sh tests/*.sh; do bash -n "$f" || exit 1; done'
if command -v shellcheck >/dev/null; then
  # SC1091: common.sh is sourced through a computed path, which shellcheck can't follow.
  check "shellcheck is clean" 'shellcheck -x -e SC1091 scripts/*.sh packaging/*.sh'
else
  echo "  skip  shellcheck not installed"
fi
check "no script ever passes -insecure outside TEST mode" '! grep -n "insecure" scripts/*.sh | grep -v "TEST\|VAC off\|never used" | grep -q .'

# A fake HOME with one bottle named Vaelos and one decoy.
FAKE_HOME="$(mktemp -d)"
BOTTLES="$FAKE_HOME/Library/Containers/com.franke.Whisky/Bottles"
mkdir -p "$BOTTLES/AAAA" "$BOTTLES/BBBB"
plutil -create xml1 "$BOTTLES/AAAA/Metadata.plist"
plutil -insert info -dictionary "$BOTTLES/AAAA/Metadata.plist"
plutil -insert info.name -string "Something Else" "$BOTTLES/AAAA/Metadata.plist"
plutil -create xml1 "$BOTTLES/BBBB/Metadata.plist"
plutil -insert info -dictionary "$BOTTLES/BBBB/Metadata.plist"
plutil -insert info.name -string "Vaelos" "$BOTTLES/BBBB/Metadata.plist"

FOUND="$(HOME="$FAKE_HOME" bash -c 'source scripts/common.sh; find_bottle')"
check "find_bottle picks the bottle named Vaelos" '[ "$FOUND" = "$BOTTLES/BBBB" ]'

EMPTY_HOME="$(mktemp -d)"
check "find_bottle fails cleanly with no bottles" '! HOME="$EMPTY_HOME" bash -c "source scripts/common.sh; find_bottle" >/dev/null'

# status.sh only reports words the app understands.
STATUS="$(HOME="$EMPTY_HOME" bash scripts/status.sh)"
check "status.sh prints a known word ($STATUS)" 'echo "$STATUS" | grep -qxE "no-whisky|no-engine|no-bottle|no-steam|ready"'

rm -rf "$FAKE_HOME" "$EMPTY_HOME"
echo "$([ $FAILURES = 0 ] && echo "all passed" || echo "$FAILURES failed")"
exit $FAILURES
