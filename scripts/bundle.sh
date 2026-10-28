#!/usr/bin/env bash
set -euo pipefail

VERSION_STR=$(tr -d '[:space:]' < VERSION 2>/dev/null || echo "1.0.0")
BUILD_NUM="100"

swift build -c release
APP_DIR="MacNAP.app/Contents"
mkdir -p "$APP_DIR/MacOS" "$APP_DIR/Resources" releases
cp .build/release/MacNAP "$APP_DIR/MacOS/MacNAP"

swift scripts/generate_icon.swift
iconutil -c icns AppIcon.iconset -o "$APP_DIR/Resources/AppIcon.icns"
rm -rf AppIcon.iconset

cat > "$APP_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>MacNAP</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.lu.MacNAP</string>
    <key>CFBundleName</key>
    <string>MacNAP</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION_STR}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUM}</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

touch MacNAP.app
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f MacNAP.app || true

ditto -c -k --keepParent MacNAP.app "releases/MacNAP-v${VERSION_STR}.zip"

echo "Built MacNAP.app v${VERSION_STR} (Build ${BUILD_NUM}) and packaged releases/MacNAP-v${VERSION_STR}.zip successfully."
