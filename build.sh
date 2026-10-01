#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

echo "================================================"
echo "   Building DeviceLauncher macOS Application    "
echo "================================================"

BUILD_DIR="$DIR/build"
APP_NAME="DeviceLauncher.app"
APP_BUNDLE="$BUILD_DIR/$APP_NAME"
CACHE_DIR="/tmp/clang_cache"

mkdir -p "$BUILD_DIR"
mkdir -p "$CACHE_DIR"

echo "==> Compiling Swift sources..."
swiftc \
  -parse-as-library \
  -O \
  -module-cache-path "$CACHE_DIR" \
  Sources/Models.swift \
  Sources/DeviceManager.swift \
  Sources/Views/IOSView.swift \
  Sources/Views/AndroidView.swift \
  Sources/Views/DoctorView.swift \
  Sources/Views/MenuBarView.swift \
  Sources/Views/LogsView.swift \
  Sources/Views/MainView.swift \
  Sources/Main.swift \
  -o "$BUILD_DIR/DeviceLauncher"

echo "==> Creating macOS App Bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/DeviceLauncher" "$APP_BUNDLE/Contents/MacOS/"
cp Resources/Info.plist "$APP_BUNDLE/Contents/"
if [ -f Resources/AppIcon.icns ]; then
  cp Resources/AppIcon.icns "$APP_BUNDLE/Contents/Resources/"
fi

# Make executable
chmod +x "$APP_BUNDLE/Contents/MacOS/DeviceLauncher"

echo "==> Successfully built $APP_BUNDLE!"

# Check arguments
if [ "$1" == "--install" ] || [ "$2" == "--install" ]; then
  echo "==> Installing to /Applications..."
  cp -R "$APP_BUNDLE" /Applications/
  echo "==> Installed to /Applications/$APP_NAME!"
fi

if [ "$1" == "--run" ] || [ "$2" == "--run" ]; then
  echo "==> Launching DeviceLauncher..."
  open "$APP_BUNDLE"
fi
