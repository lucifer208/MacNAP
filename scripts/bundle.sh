#!/usr/bin/env bash
set -euo pipefail

VERSION_STR=$(tr -d '[:space:]' < VERSION 2>/dev/null || echo "1.0.0")
BUILD_NUM="100"

echo "==> Building MacNAP for production (v${VERSION_STR} Build ${BUILD_NUM})..."
swift build -c release

APP_DIR="MacNAP.app/Contents"
mkdir -p "$APP_DIR/MacOS" "$APP_DIR/Resources" releases
cp .build/release/MacNAP "$APP_DIR/MacOS/MacNAP"

echo "==> Generating App Icon..."
swift scripts/generate_icon.swift
iconutil -c icns AppIcon.iconset -o "$APP_DIR/Resources/AppIcon.icns"
rm -rf AppIcon.iconset

echo "==> Writing Info.plist..."
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

echo "==> 1. Packaging App ZIP: releases/MacNAP-v${VERSION_STR}.zip..."
ditto -c -k --keepParent MacNAP.app "releases/MacNAP-v${VERSION_STR}.zip"

echo "==> 2. Creating Release DMG: releases/MacNAP-v${VERSION_STR}.dmg..."
DMG_STAGING="releases/dmg_staging"
rm -rf "$DMG_STAGING" "releases/MacNAP-v${VERSION_STR}.dmg" "releases/MacNAP.dmg"
mkdir -p "$DMG_STAGING"

# Copy MacNAP.app and create Applications symlink for drag-and-drop install
cp -R MacNAP.app "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

hdiutil create -volname "MacNAP" \
    -srcfolder "$DMG_STAGING" \
    -ov -format UDZO \
    "releases/MacNAP-v${VERSION_STR}.dmg"

cp "releases/MacNAP-v${VERSION_STR}.dmg" "releases/MacNAP.dmg"
rm -rf "$DMG_STAGING"

echo "==> 3. Packaging Source Code ZIP: releases/MacNAP-v${VERSION_STR}-source.zip..."
git archive --format=zip --prefix="MacNAP-v${VERSION_STR}/" HEAD -o "releases/MacNAP-v${VERSION_STR}-source.zip" 2>/dev/null || {
    # Fallback if git archive is not available or untracked
    zip -r -q "releases/MacNAP-v${VERSION_STR}-source.zip" . -x ".git/*" ".build/*" "logs/*" "releases/*" "MacNAP.app/*"
}
cp "releases/MacNAP-v${VERSION_STR}-source.zip" "releases/MacNAP-source.zip"

echo "--------------------------------------------------------"
echo "Build and Packaging Complete!"
echo "  - App Bundle:   MacNAP.app"
echo "  - Release DMG:  releases/MacNAP-v${VERSION_STR}.dmg"
echo "  - Release ZIP:  releases/MacNAP-v${VERSION_STR}.zip"
echo "  - Source ZIP:   releases/MacNAP-v${VERSION_STR}-source.zip"
echo "--------------------------------------------------------"

# Copy MacNAP.app and create Applications symlink for drag-and-drop install
cp -R MacNAP.app "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

hdiutil create -volname "MacNAP" \
    -srcfolder "$DMG_STAGING" \
    -ov -format UDZO \
    "releases/MacNAP-v${VERSION_STR}.dmg"

cp "releases/MacNAP-v${VERSION_STR}.dmg" "releases/MacNAP.dmg"
rm -rf "$DMG_STAGING"

echo "==> 3. Packaging Source Code ZIP: releases/MacNAP-v${VERSION_STR}-source.zip..."
git archive --format=zip --prefix="MacNAP-v${VERSION_STR}/" HEAD -o "releases/MacNAP-v${VERSION_STR}-source.zip" 2>/dev/null || {
    # Fallback if git archive is not available or untracked
    zip -r -q "releases/MacNAP-v${VERSION_STR}-source.zip" . -x ".git/*" ".build/*" "logs/*" "releases/*" "MacNAP.app/*"
}
cp "releases/MacNAP-v${VERSION_STR}-source.zip" "releases/MacNAP-source.zip"

echo "--------------------------------------------------------"
echo "Build and Packaging Complete!"
echo "  - App Bundle:   MacNAP.app"
echo "  - Release DMG:  releases/MacNAP-v${VERSION_STR}.dmg"
echo "  - Release ZIP:  releases/MacNAP-v${VERSION_STR}.zip"
echo "  - Source ZIP:   releases/MacNAP-v${VERSION_STR}-source.zip"
echo "--------------------------------------------------------"

