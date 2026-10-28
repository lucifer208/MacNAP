#!/usr/bin/env bash
set -euo pipefail

# Tự động tính timestamp yymmddhhss (Năm 2 số, Tháng, Ngày, Giờ, Giây)
DATE_SUFFIX=$(date +"%y%m%d%H%S")
BASE_VER="1.0.1"

if [ -n "${1:-}" ]; then
    VERSION_STR="$1"
else
    VERSION_STR="${BASE_VER}.${DATE_SUFFIX}"
fi

echo "${VERSION_STR}" > VERSION
BUILD_NUM="${DATE_SUFFIX}"

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
zip -r -q "releases/MacNAP-v${VERSION_STR}-source.zip" Sources scripts Package.swift README.md README_EN.md LICENSE CHANGELOG.md VERSION -x "*.DS_Store*"
cp "releases/MacNAP-v${VERSION_STR}-source.zip" "releases/MacNAP-source.zip"

echo "==> 4. Updating releases/latest.json..."
cat > releases/latest.json <<EOF
{
  "version": "${VERSION_STR}",
  "buildNumber": ${BUILD_NUM},
  "releaseDate": "$(date +%Y-%m-%d)",
  "downloadURL": "https://github.com/lucifer208/MacNAP/releases/download/v${VERSION_STR}/MacNAP-v${VERSION_STR}.dmg",
  "zipURL": "https://github.com/lucifer208/MacNAP/releases/download/v${VERSION_STR}/MacNAP-v${VERSION_STR}.zip",
  "sourceURL": "https://github.com/lucifer208/MacNAP/releases/download/v${VERSION_STR}/MacNAP-v${VERSION_STR}-source.zip",
  "releaseNotesVi": "Bản cập nhật MacNAP v${VERSION_STR}: Cố định hiển thị giao diện Cài đặt, tự động đánh số phiên bản theo timestamp yymmddhhss.",
  "releaseNotesEn": "MacNAP v${VERSION_STR}: Fixed settings window trigger and automated timestamped versioning."
}
EOF

echo "--------------------------------------------------------"
echo "Build and Packaging Complete!"
echo "  - App Bundle:   MacNAP.app"
echo "  - Release DMG:  releases/MacNAP-v${VERSION_STR}.dmg"
echo "  - Release ZIP:  releases/MacNAP-v${VERSION_STR}.zip"
echo "  - Source ZIP:   releases/MacNAP-v${VERSION_STR}-source.zip"
echo "--------------------------------------------------------"

