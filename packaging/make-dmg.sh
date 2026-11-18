#!/bin/bash
# Package the app into dist/Vaelos-Silicon.dmg and dist/SHA256SUMS.
#   SIGN_IDENTITY   Developer ID to sign the app and the DMG (default: ad-hoc, not notarizable)
#   NOTARY_PROFILE  keychain profile from `xcrun notarytool store-credentials`: notarize and staple the DMG
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/Vaelos Silicon.app"
DMG="dist/Vaelos-Silicon.dmg"
VOLUME="Vaelos Silicon"

packaging/build-app.sh

echo "==> Disk image"
STAGING="$(mktemp -d)"
ditto "$APP" "$STAGING/Vaelos Silicon.app"          # ditto keeps the signature and extended attributes intact
ln -s /Applications "$STAGING/Applications"         # drag-to-install target
cp build/AppIcon.icns "$STAGING/.VolumeIcon.icns"

mkdir -p dist
rm -f "$DMG" build/rw.dmg
hdiutil create -quiet -volname "$VOLUME" -srcfolder "$STAGING" -fs HFS+ -format UDRW build/rw.dmg

# Show the logo as the mounted volume's icon (needs SetFile from the Xcode tools; skipped without it).
MOUNT="$(mktemp -d)"
hdiutil attach -quiet -nobrowse -mountpoint "$MOUNT" build/rw.dmg
xcrun SetFile -a C "$MOUNT" 2>/dev/null || echo "note: SetFile not found, volume icon skipped"
hdiutil detach -quiet "$MOUNT"

# Read-only, compressed: the downloaded image can't be modified in place.
hdiutil convert -quiet build/rw.dmg -format UDZO -imagekey zlib-level=9 -o "$DMG"
rm -rf build/rw.dmg "$STAGING"

if [ -n "${SIGN_IDENTITY:-}" ]; then
  echo "==> Sign DMG"
  codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG"
fi
if [ -n "${NOTARY_PROFILE:-}" ]; then
  echo "==> Notarize"
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG"
fi

hdiutil verify -quiet "$DMG"
(cd dist && shasum -a 256 "$(basename "$DMG")" > SHA256SUMS)
cat dist/SHA256SUMS
echo "built $DMG ($(du -h "$DMG" | cut -f1))"
