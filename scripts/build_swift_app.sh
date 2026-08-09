#!/bin/bash
# Builds, signs, notarizes, staples, and verifies the DIT Renamer 1.1 release.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
RELEASE_DIR="$PROJECT_ROOT/Release"
BUILD_DIR="$PROJECT_ROOT/build_swift"
STAGED_RELEASE_DIR="$BUILD_DIR/Release"
VERSION="1.1"
APP_NAME="dit_renamer_Release_${VERSION}"
APP_BUNDLE="$STAGED_RELEASE_DIR/$APP_NAME.app"
ZIP_PATH="$STAGED_RELEASE_DIR/$APP_NAME.zip"
DMG_PATH="$STAGED_RELEASE_DIR/$APP_NAME.dmg"
SOURCE_DIR="$STAGED_RELEASE_DIR/Source Code"
SIGNING_IDENTITY="${DIT_RENAMER_SIGNING_IDENTITY:-}"
NOTARY_PROFILE="${DIT_RENAMER_NOTARY_PROFILE:-}"

fail() {
    echo "[ERROR] $1" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || fail "Required command is unavailable: $1"
}

[[ -n "$SIGNING_IDENTITY" ]] || fail "Set DIT_RENAMER_SIGNING_IDENTITY to a Developer ID Application identity."
[[ "$SIGNING_IDENTITY" == Developer\ ID\ Application:* ]] || fail "Signing identity must be a Developer ID Application certificate."
[[ -n "$NOTARY_PROFILE" ]] || fail "Set DIT_RENAMER_NOTARY_PROFILE to a notarytool keychain profile."

for required in swiftc lipo codesign security ditto hdiutil spctl xcrun git tar; do
    require_command "$required"
done

IDENTITIES="$(security find-identity -v -p codesigning 2>&1)"
[[ "$IDENTITIES" == *"$SIGNING_IDENTITY"* ]] || fail "The requested Developer ID Application identity is not available in the keychain."

echo "[PREFLIGHT] Validating notarization credentials..."
xcrun notarytool history \
    --keychain-profile "$NOTARY_PROFILE" \
    --output-format json >/dev/null || fail "The notarytool profile is unavailable or could not authenticate."

cd "$PROJECT_ROOT"
[[ -z "$(git status --porcelain)" ]] || fail "Commit all source changes and untracked files before creating a release."

SWIFT_FILES=()
while IFS= read -r -d '' source_file; do
    SWIFT_FILES+=("$source_file")
done < <(find "$PROJECT_ROOT/src_swift" -name '*.swift' -print0)
[[ ${#SWIFT_FILES[@]} -gt 0 ]] || fail "No Swift sources were found."

echo "=================================================="
echo "[BUILD] DIT Renamer $VERSION universal Developer ID release"
echo "=================================================="

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/arm64" "$BUILD_DIR/x86_64" "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"

echo "[COMPILE] Building arm64..."
swiftc -parse-as-library -O -target arm64-apple-macosx14.0 \
    -o "$BUILD_DIR/arm64/DITRenamer" \
    "${SWIFT_FILES[@]}"

echo "[COMPILE] Building x86_64..."
swiftc -parse-as-library -O -target x86_64-apple-macosx14.0 \
    -o "$BUILD_DIR/x86_64/DITRenamer" \
    "${SWIFT_FILES[@]}"

echo "[UNIVERSAL] Combining architecture slices..."
lipo -create \
    "$BUILD_DIR/arm64/DITRenamer" \
    "$BUILD_DIR/x86_64/DITRenamer" \
    -output "$APP_BUNDLE/Contents/MacOS/DITRenamer"
lipo "$APP_BUNDLE/Contents/MacOS/DITRenamer" -verify_arch arm64 x86_64

if [[ -f "$PROJECT_ROOT/AppIcon.icns" ]]; then
    cp "$PROJECT_ROOT/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi

cat <<EOF > "$APP_BUNDLE/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>DITRenamer</string>
    <key>CFBundleIdentifier</key>
    <string>com.dit.renamer.release</string>
    <key>CFBundleName</key>
    <string>DIT Renamer</string>
    <key>CFBundleDisplayName</key>
    <string>DIT Renamer</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "[SIGN] Signing app with Developer ID and secure timestamp..."
codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$APP_BUNDLE"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

echo "[NOTARY] Submitting app..."
APP_NOTARY_ZIP="$BUILD_DIR/$APP_NAME-notary.zip"
ditto -c -k --keepParent "$APP_BUNDLE" "$APP_NOTARY_ZIP"
xcrun notarytool submit "$APP_NOTARY_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP_BUNDLE"
xcrun stapler validate "$APP_BUNDLE"

echo "[GATEKEEPER] Assessing stapled app..."
spctl --assess --type execute --verbose=4 "$APP_BUNDLE"

echo "[ZIP] Packaging stapled universal app..."
ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ZIP_PATH"

echo "[DMG] Creating signed distribution image..."
DMG_STAGE="$BUILD_DIR/dmg_stage"
mkdir -p "$DMG_STAGE"
ditto "$APP_BUNDLE" "$DMG_STAGE/DIT Renamer.app"
ln -s /Applications "$DMG_STAGE/Applications"

cat <<'EOF' > "$DMG_STAGE/安装说明.txt"
DIT Renamer 已使用 Apple Developer ID 签名、完成 notarization 并附加公证票据。

安装：
1. 将 DIT Renamer.app 拖入 Applications。
2. 从 Applications 正常打开。

发布包不需要、也不提供 sudo xattr 或绕过 Gatekeeper 的修复脚本。
如果 macOS 拒绝启动，请保留原始 DMG，并向发布者报告系统版本和提示文本。
EOF

hdiutil create -volname "DIT Renamer $VERSION" -srcfolder "$DMG_STAGE" -ov -format UDZO "$DMG_PATH"
codesign --force --timestamp --sign "$SIGNING_IDENTITY" "$DMG_PATH"
codesign --verify --strict --verbose=2 "$DMG_PATH"

echo "[NOTARY] Submitting DMG..."
xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"

echo "[GATEKEEPER] Assessing stapled DMG..."
spctl --assess --type open --context context:primary-signature --verbose=4 "$DMG_PATH"

echo "[SOURCE] Exporting the exact committed source tree..."
SOURCE_ARCHIVE="$BUILD_DIR/source.tar"
mkdir -p "$SOURCE_DIR"
git archive --format=tar HEAD --output="$SOURCE_ARCHIVE"
tar -xf "$SOURCE_ARCHIVE" -C "$SOURCE_DIR"

echo "[PUBLISH] Replacing Release only after all validation passed..."
PREVIOUS_RELEASE_DIR="$PROJECT_ROOT/.Release.previous.$$"
rm -rf "$PREVIOUS_RELEASE_DIR"
if [[ -d "$RELEASE_DIR" ]]; then
    mv "$RELEASE_DIR" "$PREVIOUS_RELEASE_DIR"
fi
if ! mv "$STAGED_RELEASE_DIR" "$RELEASE_DIR"; then
    if [[ -d "$PREVIOUS_RELEASE_DIR" ]]; then
        mv "$PREVIOUS_RELEASE_DIR" "$RELEASE_DIR"
    fi
    fail "Could not publish the validated release; the previous Release directory was restored."
fi
rm -rf "$PREVIOUS_RELEASE_DIR"

APP_BUNDLE="$RELEASE_DIR/$APP_NAME.app"
ZIP_PATH="$RELEASE_DIR/$APP_NAME.zip"
DMG_PATH="$RELEASE_DIR/$APP_NAME.dmg"
SOURCE_DIR="$RELEASE_DIR/Source Code"

echo "=================================================="
echo "[SUCCESS] Signed, notarized, stapled, Gatekeeper-verified release complete"
echo "  App: $APP_BUNDLE"
echo "  Zip: $ZIP_PATH"
echo "  DMG: $DMG_PATH"
echo "  Source: $SOURCE_DIR"
echo "  Architectures: $(lipo -archs "$APP_BUNDLE/Contents/MacOS/DITRenamer")"
echo "=================================================="
