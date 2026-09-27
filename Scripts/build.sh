#!/bin/bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"

echo "🔨 Building MyCluely macOS Application..."

APP_NAME="MyCluely"
BUILD_DIR="$DIR/build"
# Assemble outside Finder/iCloud-managed Desktop metadata, then install atomically.
STAGING_DIR=$(mktemp -d /private/tmp/mycluely-build.XXXXXX)
APP_DIR="$STAGING_DIR/$APP_NAME.app"
OUTPUT_APP="$BUILD_DIR/$APP_NAME.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RESOURCES_DIR="$APP_DIR/Contents/Resources"
mkdir -p "$DIR/.build"
CACHE_DIR=$(mktemp -d "$DIR/.build/module-cache.XXXXXX")
trap 'rm -rf "$CACHE_DIR" "$STAGING_DIR"' EXIT

mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"
mkdir -p "$CACHE_DIR"

# Collect all swift files
SWIFT_FILES=$(find Sources -name "*.swift")

echo "📦 Compiling Swift sources..."
swiftc -O -target "$(uname -m)-apple-macos14.0" \
    -Xfrontend -disable-sandbox \
    -module-cache-path "$CACHE_DIR" \
    -framework Foundation \
    -framework AppKit \
    -framework SwiftUI \
    -framework ScreenCaptureKit \
    -framework Speech \
    -framework AVFoundation \
    -framework CoreMedia \
    -framework CryptoKit \
    -framework AuthenticationServices \
    -framework Security \
    -o "$MACOS_DIR/$APP_NAME" \
    $SWIFT_FILES

echo "📄 Copying Info.plist..."
cp Resources/Info.plist "$APP_DIR/Contents/Info.plist"

echo "🧹 Stripping Finder metadata..."
find "$APP_DIR" -name ".DS_Store" -delete 2>/dev/null || true
find "$APP_DIR" -name "._*" -delete 2>/dev/null || true
xattr -cr "$APP_DIR"
# Finder/iCloud can retain bundle-root FinderInfo after recursive clearing.
xattr -d com.apple.FinderInfo "$APP_DIR" 2>/dev/null || true

echo "🔐 Ad-hoc code signing $APP_NAME.app with hardened runtime..."
codesign --force --deep --sign - --options runtime --entitlements Resources/MyCluely.entitlements "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"

mkdir -p "$BUILD_DIR"
if [ -e "$OUTPUT_APP" ]; then
    mv "$OUTPUT_APP" "$STAGING_DIR/previous.app"
fi
if ! ditto --noextattr --norsrc "$APP_DIR" "$OUTPUT_APP"; then
    if [ -e "$STAGING_DIR/previous.app" ]; then
        mv "$STAGING_DIR/previous.app" "$OUTPUT_APP"
    fi
    exit 1
fi
xattr -cr "$OUTPUT_APP"
# File Provider may asynchronously add FinderInfo when it observes a new .app.
# Retry only metadata removal; never accept an invalid code signature.
VERIFIED=0
for attempt in {1..10}; do
    xattr -d com.apple.FinderInfo "$OUTPUT_APP" 2>/dev/null || true
    if codesign --verify --deep --strict "$OUTPUT_APP" 2>/dev/null; then
        VERIFIED=1
        break
    fi
    sleep 0.2
done
if [ "$VERIFIED" -ne 1 ]; then
    codesign --verify --deep --strict "$OUTPUT_APP"
    exit 1
fi
# Preserve a metadata-free signed bundle even if Finder later annotates the .app.
ditto -c -k --noextattr --norsrc --keepParent "$APP_DIR" "$BUILD_DIR/$APP_NAME.zip"
SIZE=$(du -sh "$OUTPUT_APP" | cut -f1)
echo "✅ Build complete! App created at: $OUTPUT_APP (Size: $SIZE)"
echo "📦 Clean signed archive: $BUILD_DIR/$APP_NAME.zip"
