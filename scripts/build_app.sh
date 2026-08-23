#!/bin/bash
set -e

APP_NAME="Retrazo"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "=== Building $APP_NAME for macOS (Release) ==="

# 1. Generate AppIcon.icns if needed
if [ ! -f "Sources/Retrazo/Resources/AppIcon.icns" ]; then
    echo "Generating AppIcon.icns..."
    ./scripts/generate_icon.sh
fi

# 2. Compile Swift binary with optimizations
echo "Compiling with Swift Package Manager (Release)..."
swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)/$APP_NAME"

if [ ! -f "$BIN_PATH" ]; then
    echo "Error: Binary not found at $BIN_PATH"
    exit 1
fi

# 3. Create .app bundle structure
echo "Creating $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy binary
cp "$BIN_PATH" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

# Copy Info.plist
if [ -f "Support/Info.plist" ]; then
    cp "Support/Info.plist" "$CONTENTS_DIR/Info.plist"
elif [ -f "Sources/Retrazo/Resources/Info.plist" ]; then
    cp "Sources/Retrazo/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
fi

# Copy AppIcon.icns
if [ -f "Sources/Retrazo/Resources/AppIcon.icns" ]; then
    cp "Sources/Retrazo/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

# Copy any SPM resource bundles
BIN_DIR="$(swift build -c release --show-bin-path)"
for bundle in "$BIN_DIR"/*.bundle; do
    if [ -d "$bundle" ]; then
        echo "Copying resource bundle $(basename "$bundle")..."
        cp -R "$bundle" "$RESOURCES_DIR/"
    fi
done

# 4. Sign the app bundle (Ad-Hoc)
echo "Signing $APP_BUNDLE (ad-hoc)..."
codesign --force --deep --sign - "$APP_BUNDLE"

# 5. Create ZIP distribution
echo "Creating $BUILD_DIR/$APP_NAME-macOS.zip..."
(cd "$BUILD_DIR" && zip -r -q -y "$APP_NAME-macOS.zip" "$APP_NAME.app")

echo "=== Build Complete! ==="
echo "App Bundle: $APP_BUNDLE"
echo "Zip File:   $BUILD_DIR/$APP_NAME-macOS.zip"
