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

# Tagged GitHub builds inject the release version without modifying source files.
if [ -n "${RETRAZO_VERSION:-}" ]; then
    plutil -replace CFBundleShortVersionString -string "$RETRAZO_VERSION" "$CONTENTS_DIR/Info.plist"
fi
if [ -n "${RETRAZO_BUILD_NUMBER:-}" ]; then
    plutil -replace CFBundleVersion -string "$RETRAZO_BUILD_NUMBER" "$CONTENTS_DIR/Info.plist"
fi

# Copy AppIcon.icns
if [ -f "Sources/Retrazo/Resources/AppIcon.icns" ]; then
    cp "Sources/Retrazo/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

# Compile the native layered macOS icon when the full Xcode toolchain is
# available. macOS 26 reads the compiled Assets.car, while AppIcon.icns stays
# in the bundle as the fallback for older systems and local CLT-only builds.
ICON_COMPOSER_SOURCE="Assets/AppIcon.icon"
if [ -d "$ICON_COMPOSER_SOURCE" ]; then
    if ACTOOL_PATH="$(xcrun --find actool 2>/dev/null)" && [ -x "$ACTOOL_PATH" ]; then
        echo "Compiling native AppIcon.icon..."
        ICON_BUILD_DIR="$(mktemp -d)"
        ICON_PARTIAL_PLIST="$ICON_BUILD_DIR/assetcatalog_generated_info.plist"

        "$ACTOOL_PATH" "$ICON_COMPOSER_SOURCE" \
            --compile "$ICON_BUILD_DIR" \
            --app-icon AppIcon \
            --include-all-app-icons \
            --enable-on-demand-resources NO \
            --target-device mac \
            --minimum-deployment-target 13.0 \
            --platform macosx \
            --output-partial-info-plist "$ICON_PARTIAL_PLIST" \
            --output-format human-readable-text \
            --notices \
            --warnings

        if [ ! -f "$ICON_BUILD_DIR/Assets.car" ]; then
            echo "Error: actool did not produce Assets.car"
            exit 1
        fi

        cp "$ICON_BUILD_DIR/Assets.car" "$RESOURCES_DIR/Assets.car"
        if [ -f "$ICON_BUILD_DIR/AppIcon.icns" ]; then
            cp "$ICON_BUILD_DIR/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
        fi

        if ! plutil -replace CFBundleIconName -string AppIcon "$CONTENTS_DIR/Info.plist" 2>/dev/null; then
            plutil -insert CFBundleIconName -string AppIcon "$CONTENTS_DIR/Info.plist"
        fi

        rm -rf "$ICON_BUILD_DIR"
    else
        echo "Full Xcode actool not found; using AppIcon.icns fallback."
    fi
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
