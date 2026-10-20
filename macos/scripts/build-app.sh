#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Ultra-W Tiling"
BUNDLE_ID="${BUNDLE_ID:-org.powerhouse.UltraWTiling}"
BUILD_CONFIG="${BUILD_CONFIG:-release}"
APP_DIR="$ROOT/dist/$APP_NAME.app"
EXECUTABLE="$ROOT/.build/$BUILD_CONFIG/UltraWTiling"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:--}"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This build script must run on macOS." >&2
  exit 1
fi

swift build --package-path "$ROOT" -c "$BUILD_CONFIG"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$EXECUTABLE" "$APP_DIR/Contents/MacOS/UltraWTiling"

cat > "$APP_DIR/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>UltraWTiling</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSInputMonitoringUsageDescription</key>
  <string>Ultra-W Tiling watches Option-drag gestures to preview and place windows into ultrawide zones.</string>
  <key>NSAccessibilityUsageDescription</key>
  <string>Ultra-W Tiling uses Accessibility to move and resize windows into selected zones.</string>
</dict>
</plist>
EOF

if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign "$CODESIGN_IDENTITY" "$APP_DIR"
fi

echo "Built $APP_DIR"
