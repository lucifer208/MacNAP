#!/usr/bin/env bash
set -euo pipefail

swift build -c release
APP_DIR="MacNAP.app/Contents"
mkdir -p "$APP_DIR/MacOS" "$APP_DIR/Resources"
cp .build/release/MacNAP "$APP_DIR/MacOS/MacNAP"

cat > "$APP_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>MacNAP</string>
    <key>CFBundleIdentifier</key>
    <string>com.lu.MacNAP</string>
    <key>CFBundleName</key>
    <string>MacNAP</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "Built MacNAP.app successfully."
