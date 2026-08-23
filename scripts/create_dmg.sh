#!/bin/bash
set -e

APP_NAME="Retrazo"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
DMG_NAME="$APP_NAME-macOS.dmg"
DMG_PATH="$BUILD_DIR/$DMG_NAME"
TEMP_DMG_DIR="$(mktemp -d)/dmg_staging"

if [ ! -d "$APP_BUNDLE" ]; then
    echo "App bundle not found! Building app first..."
    ./scripts/build_app.sh
fi

echo "=== Packaging $DMG_NAME ==="

mkdir -p "$TEMP_DMG_DIR"
cp -R "$APP_BUNDLE" "$TEMP_DMG_DIR/"
ln -s /Applications "$TEMP_DMG_DIR/Applications"

rm -f "$DMG_PATH"

echo "Creating DMG image..."
hdiutil create -volname "$APP_NAME" \
               -srcfolder "$TEMP_DMG_DIR" \
               -ov -format UDZO \
               "$DMG_PATH"

rm -rf "$TEMP_DMG_DIR"

echo "=== DMG Created Successfully at $DMG_PATH ==="
