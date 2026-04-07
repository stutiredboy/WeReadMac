#!/bin/bash
set -euo pipefail

SCHEME="WeReadMac"
CONFIGURATION="Release"
APP_VERSION="1.0.3"
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DMG="${PROJECT_ROOT}/WeReadMac.dmg"

ARCHIVE_PATH="/tmp/${SCHEME}.xcarchive"
EXPORT_PATH="/tmp/${SCHEME}-export"
EXPORT_OPTIONS="/tmp/${SCHEME}-exportOptions.plist"
STAGING_DIR="/tmp/${SCHEME}-dmg-staging"

cleanup() {
    rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH" "$EXPORT_OPTIONS" "$STAGING_DIR"
}
trap cleanup EXIT

echo "==> Archiving ${SCHEME} (${CONFIGURATION})..."
xcodebuild clean archive \
    -scheme "$SCHEME" -configuration "$CONFIGURATION" \
    -archivePath "$ARCHIVE_PATH" \
    MARKETING_VERSION="${APP_VERSION}" \
    -quiet

echo "==> Exporting .app..."
cat > "$EXPORT_OPTIONS" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>mac-application</string>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
EOF
xcodebuild -exportArchive -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" -exportOptionsPlist "$EXPORT_OPTIONS" 2>/dev/null

echo "==> Creating DMG..."
rm -rf "$STAGING_DIR" && mkdir -p "$STAGING_DIR"
cp -R "${EXPORT_PATH}/${SCHEME}.app" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

rm -f "$OUTPUT_DMG"
hdiutil create -volname "$SCHEME" -srcfolder "$STAGING_DIR" \
    -ov -format UDZO "$OUTPUT_DMG" -quiet

SIZE=$(du -h "$OUTPUT_DMG" | cut -f1)
echo "==> Done: ${OUTPUT_DMG} (${SIZE})"
