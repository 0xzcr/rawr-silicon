#!/bin/bash
# Build "build/Vaelos Silicon.app".
#   SIGN_IDENTITY="Developer ID Application: Name (TEAMID)"   sign for distribution (default: ad-hoc)
# Needs: Xcode command line tools (swiftc, codesign, iconutil) and zig (for the Windows mic recorder).
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="$(cat VERSION)"
APP="build/Vaelos Silicon.app"
RESOURCES="$APP/Contents/Resources"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$RESOURCES/scripts" "$RESOURCES/bin"

echo "==> Swift app $VERSION"
# arm64 only: Whisky's Wine build, and so this app, is Apple Silicon only.
swiftc -O -swift-version 5 -target arm64-apple-macos14 app/*.swift -o "$APP/Contents/MacOS/Vaelos Silicon"

echo "==> Windows mic recorder"
zig cc -target x86_64-windows-gnu -O2 tools/micrec.c -lwinmm -o "$RESOURCES/bin/micrec.exe"
rm -f "$RESOURCES/bin/micrec.pdb"

echo "==> Scripts"
cp scripts/*.sh "$RESOURCES/scripts/"
chmod 755 "$RESOURCES/scripts/"*.sh

echo "==> Icon"
swift packaging/make-icon.swift build/icon-1024.png >/dev/null
ICONSET="build/AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
# name:pixels for every size macOS asks for.
for entry in 16x16:16 16x16@2x:32 32x32:32 32x32@2x:64 128x128:128 128x128@2x:256 256x256:256 256x256@2x:512 512x512:512 512x512@2x:1024; do
  sips -z "${entry#*:}" "${entry#*:}" build/icon-1024.png --out "$ICONSET/icon_${entry%%:*}.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o build/AppIcon.icns
cp build/AppIcon.icns "$RESOURCES/AppIcon.icns"

sed "s/__VERSION__/$VERSION/g" packaging/Info.plist > "$APP/Contents/Info.plist"

echo "==> Sign (hardened runtime)"
IDENTITY="${SIGN_IDENTITY:--}"
TIMESTAMP=()
# A secure timestamp is required for notarization, and only possible with a real identity.
[ "$IDENTITY" != "-" ] && TIMESTAMP=(--timestamp)
codesign --force --options runtime --entitlements packaging/entitlements.plist \
  ${TIMESTAMP[@]+"${TIMESTAMP[@]}"} --sign "$IDENTITY" "$APP"
codesign --verify --strict --verbose=2 "$APP"
echo "built $APP"
