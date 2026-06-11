#!/bin/bash
set -e

FAVICON_PATH="docs/favicon.png"
ICONSET_DIR="AppIcon.iconset"
ICNS_FILE="AppIcon.icns"

echo "=== 1. Creating iconset structure ==="
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

echo "=== 2. Generating scaled PNG sizes via sips ==="
# Standard resolutions
sips -s format png -z 16 16     "$FAVICON_PATH" --out "$ICONSET_DIR/icon_16x16.png"
sips -s format png -z 32 32     "$FAVICON_PATH" --out "$ICONSET_DIR/icon_16x16@2x.png"
sips -s format png -z 32 32     "$FAVICON_PATH" --out "$ICONSET_DIR/icon_32x32.png"
sips -s format png -z 64 64     "$FAVICON_PATH" --out "$ICONSET_DIR/icon_32x32@2x.png"
sips -s format png -z 128 128   "$FAVICON_PATH" --out "$ICONSET_DIR/icon_128x128.png"
sips -s format png -z 256 256   "$FAVICON_PATH" --out "$ICONSET_DIR/icon_128x128@2x.png"
sips -s format png -z 256 256   "$FAVICON_PATH" --out "$ICONSET_DIR/icon_256x256.png"
sips -s format png -z 512 512   "$FAVICON_PATH" --out "$ICONSET_DIR/icon_256x256@2x.png"
sips -s format png -z 512 512   "$FAVICON_PATH" --out "$ICONSET_DIR/icon_512x512.png"
sips -s format png -z 1024 1024 "$FAVICON_PATH" --out "$ICONSET_DIR/icon_512x512@2x.png"

echo "=== 3. Compiling iconset into a native macOS .icns file ==="
iconutil -c icns "$ICONSET_DIR"

echo "=== 4. Cleaning up temporary iconset directory ==="
rm -rf "$ICONSET_DIR"

echo "=== Success! Generated: $ICNS_FILE ==="
