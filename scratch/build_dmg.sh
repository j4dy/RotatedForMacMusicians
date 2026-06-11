#!/bin/bash
set -e

APP_NAME="Vecto"
BINARY_NAME="net.j4dy.RotatedBrowserApp"
DMG_NAME="Vecto.dmg"
RELEASE_DIR="release_build"

echo "=== 1. Cleaning old build artifacts ==="
rm -rf "$RELEASE_DIR"
rm -f "$DMG_NAME"
mkdir -p "$RELEASE_DIR/${APP_NAME}.app/Contents/MacOS"
mkdir -p "$RELEASE_DIR/${APP_NAME}.app/Contents/Resources"

echo "=== 2. Compiling native optimized binary ==="
swiftc -O RotatedBrowserApp.swift ContentView.swift WebView.swift PDFViewWrapper.swift Analytics.swift -o "$RELEASE_DIR/${APP_NAME}.app/Contents/MacOS/${APP_NAME}"

echo "=== 3. Copying configuration Info.plist ==="
cp Info.plist "$RELEASE_DIR/${APP_NAME}.app/Contents/Info.plist"
cp AppIcon.icns "$RELEASE_DIR/${APP_NAME}.app/Contents/Resources/AppIcon.icns"

echo "=== 4. Structuring Applications folder symlink ==="
ln -s /Applications "$RELEASE_DIR/Applications"

echo "=== 5. Packaging into a native disk image (.dmg) ==="
hdiutil create -volname "${APP_NAME} Installer" -srcfolder "$RELEASE_DIR" -ov -format UDZO "$DMG_NAME"

echo "=== 6. Cleanup release build workspace ==="
rm -rf "$RELEASE_DIR"

echo "=== Done! Generated: $DMG_NAME ==="
