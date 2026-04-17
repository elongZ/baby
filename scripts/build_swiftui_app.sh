#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="PediatricsRAGMacApp"
MAC_APP_DIR="$ROOT_DIR/apps/mac/mac-app"
DIST_DIR="$ROOT_DIR/workspace/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
RELEASE_BIN_DIR="$(cd "$MAC_APP_DIR" && swift build --configuration release --show-bin-path)"
EXECUTABLE_PATH="$RELEASE_BIN_DIR/$APP_NAME"
ICONSET_DIR="$MAC_APP_DIR/AppIcon.iconset"
ICON_FILE="$RESOURCES_DIR/AppIcon.icns"

mkdir -p "$DIST_DIR"
rm -rf "$APP_DIR"

python3 "$ROOT_DIR/scripts/generate_app_icon.py"

cd "$MAC_APP_DIR"
swift build --configuration release

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$EXECUTABLE_PATH" "$MACOS_DIR/$APP_NAME"
iconutil -c icns "$ICONSET_DIR" -o "$ICON_FILE"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>PediatricsRAGMacApp</string>
    <key>CFBundleIdentifier</key>
    <string>com.local.pediatrics-rag-swiftui</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleName</key>
    <string>PediatricsRAGMacApp</string>
    <key>CFBundleDisplayName</key>
    <string>PediatricsRAGMacApp</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>0.1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

cat > "$RESOURCES_DIR/README-launch.txt" <<EOF
This app expects to run near the repository root:
$ROOT_DIR

If you move the app elsewhere, set:
BABY_APP_PROJECT_ROOT=$ROOT_DIR
EOF

echo "Built app bundle: $APP_DIR"
