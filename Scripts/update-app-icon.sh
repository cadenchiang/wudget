#!/bin/bash
# update-app-icon.sh — replace the app icon everywhere from an Icon Composer .icon bundle.
#
# Usage: Scripts/update-app-icon.sh <path-to-icon.icon>
#   e.g. Scripts/update-app-icon.sh ~/Downloads/wudget_icon.icon
#
# Does three things:
#   1. Copies the .icon bundle over WalletBudget/AppIcon.icon (home-screen icon, both targets).
#   2. Re-renders the flat 1024px PNG with actool (the pre-iOS-11 deployment target makes actool
#      emit standalone PNGs instead of an Assets.car).
#   3. Drops that PNG into AppIconImage.imageset (in-app logo, e.g. AboutView) and the legacy
#      AppIcon.appiconset (pre-iOS-26 fallback).
#
# After running: rebuild and reinstall. If the home-screen icon looks stale, that's the iOS
# Springboard icon cache — delete the app and reinstall.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${1:?usage: update-app-icon.sh <path-to-icon.icon>}"
ICON_DEST="$REPO/WalletBudget/AppIcon.icon"
RENDER_DIR="$(mktemp -d)"
trap 'rm -rf "$RENDER_DIR"' EXIT

[ -f "$SRC/icon.json" ] || { echo "error: $SRC is not an Icon Composer .icon bundle (no icon.json)"; exit 1; }

echo "1/3 Copying $SRC -> $ICON_DEST"
rm -rf "$ICON_DEST"
cp -R "$SRC" "$ICON_DEST"

echo "2/3 Rendering flat PNGs with actool"
xcrun actool "$ICON_DEST" --compile "$RENDER_DIR" \
    --platform iphoneos --minimum-deployment-target 10.0 \
    --app-icon AppIcon --output-partial-info-plist "$RENDER_DIR/partial.plist" > /dev/null
PNG="$RENDER_DIR/AppIcon1024x1024.png"
[ -f "$PNG" ] || { echo "error: actool did not produce AppIcon1024x1024.png"; exit 1; }

echo "3/3 Updating AppIconImage.imageset and AppIcon.appiconset"
cp "$PNG" "$REPO/WalletBudget/Assets.xcassets/AppIconImage.imageset/AppIcon1024.png"
cp "$PNG" "$REPO/WalletBudget/Assets.xcassets/AppIcon.appiconset/AppIcon1024.png"

echo "Done. Rebuild + reinstall to see the new icon."
