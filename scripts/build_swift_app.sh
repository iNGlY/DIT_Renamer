#!/bin/bash
# Builds a universal DIT Renamer release with Sparkle-based updates.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
RELEASE_DIR="$PROJECT_ROOT/Release"
BUILD_DIR="$PROJECT_ROOT/build_swift"
RELEASE_DIR="${DIT_RENAMER_RELEASE_DIR:-$RELEASE_DIR}"
BUILD_DIR="${DIT_RENAMER_BUILD_DIR:-$BUILD_DIR}"
STAGED_RELEASE_DIR="$BUILD_DIR/Release"
VERSION="${DIT_RENAMER_VERSION:-1.1.1}"
BUILD_NUMBER="${DIT_RENAMER_BUILD_NUMBER:-1110}"
SPARKLE_PUBLIC_ED_KEY="${DIT_RENAMER_SPARKLE_PUBLIC_ED_KEY:-+X/X+R9CiO+z1igmTrgXdJWl6PPSD5zs0AS/iOq2gmk=}"
SPARKLE_FEED_URL="${DIT_RENAMER_SPARKLE_FEED_URL:-https://ingly.github.io/DIT_Renamer/appcast.xml}"
RELEASE_MODE="${DIT_RENAMER_RELEASE_MODE:-developer-id}"
case "$RELEASE_MODE" in
    developer-id)
        ARTIFACT_SUFFIX=""
        DMG_VOLUME_NAME="DIT Renamer $VERSION"
        DMG_INSTRUCTIONS_LABEL=""
        ;;
    adhoc)
        ARTIFACT_SUFFIX="-adhoc-unnotarized"
        DMG_VOLUME_NAME="DIT Renamer $VERSION Ad-hoc"
        DMG_INSTRUCTIONS_LABEL="Ad-hoc 预发布版"
        ;;
    test)
        ARTIFACT_SUFFIX="-test-adhoc-unnotarized"
        DMG_VOLUME_NAME="DIT Renamer $VERSION Test"
        DMG_INSTRUCTIONS_LABEL="Test 测试版"
        ;;
    *)
        echo "[ERROR] DIT_RENAMER_RELEASE_MODE must be 'developer-id', 'adhoc', or 'test'." >&2
        exit 1
        ;;
esac
APP_NAME="dit_renamer_Release_${VERSION}${ARTIFACT_SUFFIX}"
APP_BUNDLE="$STAGED_RELEASE_DIR/DIT Renamer.app"
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

for required in swiftc lipo codesign ditto hdiutil git tar shasum curl; do
    require_command "$required"
done

if [[ "$RELEASE_MODE" == "developer-id" ]]; then
    for required in security spctl xcrun; do
        require_command "$required"
    done
    [[ -n "$SIGNING_IDENTITY" ]] || fail "Set DIT_RENAMER_SIGNING_IDENTITY to a Developer ID Application identity."
    [[ "$SIGNING_IDENTITY" == Developer\ ID\ Application:* ]] || fail "Signing identity must be a Developer ID Application certificate."
    [[ -n "$NOTARY_PROFILE" ]] || fail "Set DIT_RENAMER_NOTARY_PROFILE to a notarytool keychain profile."

    IDENTITIES="$(security find-identity -v -p codesigning 2>&1)"
    [[ "$IDENTITIES" == *"$SIGNING_IDENTITY"* ]] || fail "The requested Developer ID Application identity is not available in the keychain."

    echo "[PREFLIGHT] Validating notarization credentials..."
    xcrun notarytool history \
        --keychain-profile "$NOTARY_PROFILE" \
        --output-format json >/dev/null || fail "The notarytool profile is unavailable or could not authenticate."
else
    if [[ "$RELEASE_MODE" == "test" ]]; then
        echo "[WARNING] Building a 1.2 Test ad-hoc signed, unnotarized package."
        echo "[WARNING] This package is for controlled testing and is not a normal end-user release."
    else
        echo "[WARNING] Building an ad-hoc signed, unnotarized release."
        echo "[WARNING] Gatekeeper acceptance is not expected and this build is not suitable as a normal end-user release."
    fi
fi

cd "$PROJECT_ROOT"
if [[ "${DIT_RENAMER_ALLOW_DIRTY_BUILD:-0}" == "1" ]]; then
    echo "[WARNING] Dirty-build override enabled; Release metadata is for local validation only."
else
    [[ -z "$(git status --porcelain)" ]] || fail "Commit all source changes and untracked files before creating a release."
fi

SPARKLE_ROOT="$(bash "$SCRIPT_DIR/bootstrap_sparkle.sh")"
SPARKLE_FRAMEWORK_SOURCE="$SPARKLE_ROOT/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
SPARKLE_FRAMEWORK_DIR="$SPARKLE_ROOT/Sparkle.xcframework/macos-arm64_x86_64"
[[ -d "$SPARKLE_FRAMEWORK_SOURCE" ]] || fail "Sparkle framework is unavailable."

SWIFT_FILES=()
while IFS= read -r -d '' source_file; do
    SWIFT_FILES+=("$source_file")
done < <(find "$PROJECT_ROOT/src_swift" -name '*.swift' -print0)
[[ ${#SWIFT_FILES[@]} -gt 0 ]] || fail "No Swift sources were found."

echo "=================================================="
echo "[BUILD] DIT Renamer $VERSION universal $RELEASE_MODE release"
echo "=================================================="

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/arm64" "$BUILD_DIR/x86_64" "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources" "$APP_BUNDLE/Contents/Frameworks"

echo "[COMPILE] Building arm64..."
swiftc -parse-as-library -O -target arm64-apple-macosx14.0 \
    -F "$SPARKLE_FRAMEWORK_DIR" -framework Sparkle \
    -Xlinker -rpath -Xlinker '@executable_path/../Frameworks' \
    -o "$BUILD_DIR/arm64/DITRenamer" \
    "${SWIFT_FILES[@]}"

echo "[COMPILE] Building x86_64..."
swiftc -parse-as-library -O -target x86_64-apple-macosx14.0 \
    -F "$SPARKLE_FRAMEWORK_DIR" -framework Sparkle \
    -Xlinker -rpath -Xlinker '@executable_path/../Frameworks' \
    -o "$BUILD_DIR/x86_64/DITRenamer" \
    "${SWIFT_FILES[@]}"

echo "[UNIVERSAL] Combining architecture slices..."
lipo -create \
    "$BUILD_DIR/arm64/DITRenamer" \
    "$BUILD_DIR/x86_64/DITRenamer" \
    -output "$APP_BUNDLE/Contents/MacOS/DITRenamer"
lipo "$APP_BUNDLE/Contents/MacOS/DITRenamer" -verify_arch arm64 x86_64

echo "[EMBED] Copying Sparkle.framework..."
ditto "$SPARKLE_FRAMEWORK_SOURCE" "$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"

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
    <string>${BUILD_NUMBER}</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>SUFeedURL</key>
    <string>${SPARKLE_FEED_URL}</string>
    <key>SUPublicEDKey</key>
    <string>${SPARKLE_PUBLIC_ED_KEY}</string>
    <key>SUEnableAutomaticChecks</key>
    <false/>
    <key>SUAutomaticallyUpdate</key>
    <false/>
    <key>SUAllowsAutomaticUpdates</key>
    <false/>
</dict>
</plist>
EOF

sign_nested_code() {
    local identity="$1"
    local framework="$APP_BUNDLE/Contents/Frameworks/Sparkle.framework/Versions/B"
    local sign_options=(--force --sign "$identity")
    if [[ "$RELEASE_MODE" == "developer-id" ]]; then
        sign_options+=(--options runtime --timestamp)
    fi

    if [[ -d "$framework/XPCServices" ]]; then
        for service in "$framework/XPCServices"/*.xpc; do
            [[ -e "$service" ]] || continue
            if [[ "$(basename "$service")" == "Downloader.xpc" && "$RELEASE_MODE" == "developer-id" ]]; then
                codesign "${sign_options[@]}" --preserve-metadata=entitlements "$service"
            else
                codesign "${sign_options[@]}" "$service"
            fi
        done
    fi
    codesign "${sign_options[@]}" "$framework/Autoupdate"
    codesign "${sign_options[@]}" "$framework/Updater.app"
    codesign "${sign_options[@]}" "$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"
    codesign "${sign_options[@]}" "$APP_BUNDLE"
}

if [[ "$RELEASE_MODE" == "developer-id" ]]; then
    echo "[SIGN] Signing Sparkle helpers and app with Developer ID and secure timestamp..."
    sign_nested_code "$SIGNING_IDENTITY"
else
    echo "[SIGN] Applying ad-hoc signatures to Sparkle helpers and app..."
    sign_nested_code -
fi
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

if [[ "$RELEASE_MODE" == "developer-id" ]]; then
    echo "[NOTARY] Submitting app..."
    APP_NOTARY_ZIP="$BUILD_DIR/$APP_NAME-notary.zip"
    ditto -c -k --keepParent "$APP_BUNDLE" "$APP_NOTARY_ZIP"
    xcrun notarytool submit "$APP_NOTARY_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$APP_BUNDLE"
    xcrun stapler validate "$APP_BUNDLE"

    echo "[GATEKEEPER] Assessing stapled app..."
    spctl --assess --type execute --verbose=4 "$APP_BUNDLE"
fi

echo "[ZIP] Packaging universal app..."
ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ZIP_PATH"

echo "[DMG] Creating distribution image..."
DMG_STAGE="$BUILD_DIR/dmg_stage"
mkdir -p "$DMG_STAGE"
ditto "$APP_BUNDLE" "$DMG_STAGE/DIT Renamer.app"
ln -s /Applications "$DMG_STAGE/Applications"
[[ -L "$DMG_STAGE/Applications" ]] || fail "DMG Applications shortcut was not created."
for legal_file in LICENSE NOTICE; do
    [[ -f "$PROJECT_ROOT/$legal_file" ]] || fail "Missing legal file: $legal_file"
    cp "$PROJECT_ROOT/$legal_file" "$DMG_STAGE/$legal_file"
    cp "$PROJECT_ROOT/$legal_file" "$STAGED_RELEASE_DIR/$legal_file"
done

if [[ "$RELEASE_MODE" == "developer-id" ]]; then
    cat <<'EOF' > "$DMG_STAGE/安装说明.txt"
DIT Renamer 已使用 Apple Developer ID 签名、完成 notarization 并附加公证票据。

安装：
1. 将 DIT Renamer.app 拖入 Applications。
2. 从 Applications 正常打开。

发布包不需要、也不提供 sudo xattr 或绕过 Gatekeeper 的修复脚本。
如果 macOS 拒绝启动，请保留原始 DMG，并向发布者报告系统版本和提示文本。
EOF
else
    cat <<EOF > "$DMG_STAGE/安装说明.txt"
DIT Renamer $VERSION $DMG_INSTRUCTIONS_LABEL

此构建未使用 Apple Developer ID 签名，也没有经过 Apple notarization。
macOS Gatekeeper 可能阻止从 GitHub 下载的应用直接启动，因此本包不能视为“即开即用”的正式分发版本。

安装：
1. 将 DIT Renamer.app 拖入 Applications。
2. 首次启动若被阻止，请在“系统设置 > 隐私与安全性”中核对应用来源并选择“仍要打开”。

本发布包不包含 sudo、xattr、隔离属性清除脚本或其他自动绕过 Gatekeeper 的工具。
EOF
fi

hdiutil create -volname "$DMG_VOLUME_NAME" -srcfolder "$DMG_STAGE" -ov -format UDZO "$DMG_PATH"
if [[ "$RELEASE_MODE" == "developer-id" ]]; then
    codesign --force --timestamp --sign "$SIGNING_IDENTITY" "$DMG_PATH"
else
    codesign --force --sign - "$DMG_PATH"
fi
codesign --verify --strict --verbose=2 "$DMG_PATH"

if [[ "$RELEASE_MODE" == "developer-id" ]]; then
    echo "[NOTARY] Submitting DMG..."
    xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG_PATH"
    xcrun stapler validate "$DMG_PATH"

    echo "[GATEKEEPER] Assessing stapled DMG..."
    spctl --assess --type open --context context:primary-signature --verbose=4 "$DMG_PATH"
fi

echo "[SOURCE] Exporting the exact committed source tree..."
SOURCE_ARCHIVE="$BUILD_DIR/source.tar"
mkdir -p "$SOURCE_DIR"
git archive --format=tar HEAD --output="$SOURCE_ARCHIVE"
tar -xf "$SOURCE_ARCHIVE" -C "$SOURCE_DIR"

RELEASE_NOTES_PATH="$PROJECT_ROOT/docs/github_release_notes_$VERSION.md"
if [[ -f "$RELEASE_NOTES_PATH" ]]; then
    cp "$RELEASE_NOTES_PATH" "$STAGED_RELEASE_DIR/GITHUB_RELEASE_NOTES.md"
fi
RELEASE_REQUIREMENTS_PATH="$PROJECT_ROOT/docs/github_release_$VERSION.md"
if [[ -f "$RELEASE_REQUIREMENTS_PATH" ]]; then
    cp "$RELEASE_REQUIREMENTS_PATH" "$STAGED_RELEASE_DIR/GITHUB_RELEASE_REQUIREMENTS.md"
fi

(
    cd "$STAGED_RELEASE_DIR"
    shasum -a 256 "$(basename "$ZIP_PATH")" "$(basename "$DMG_PATH")" > SHA256SUMS.txt
    printf 'commit=%s\nrelease_mode=%s\nversion=%s\nbuild=%s\narchitectures=arm64 x86_64\n' \
        "$(git -C "$PROJECT_ROOT" rev-parse HEAD)" "$RELEASE_MODE" "$VERSION" "$BUILD_NUMBER" > RELEASE_METADATA.txt
)

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

APP_BUNDLE="$RELEASE_DIR/DIT Renamer.app"
ZIP_PATH="$RELEASE_DIR/$APP_NAME.zip"
DMG_PATH="$RELEASE_DIR/$APP_NAME.dmg"
SOURCE_DIR="$RELEASE_DIR/Source Code"
CHECKSUM_PATH="$RELEASE_DIR/SHA256SUMS.txt"

echo "=================================================="
if [[ "$RELEASE_MODE" == "developer-id" ]]; then
    echo "[SUCCESS] Signed, notarized, stapled, Gatekeeper-verified release complete"
elif [[ "$RELEASE_MODE" == "test" ]]; then
    echo "[SUCCESS] 1.2 Test ad-hoc signed package complete"
    echo "  WARNING: This is a controlled test build and is not notarized."
else
    echo "[SUCCESS] Ad-hoc signed, unnotarized release complete"
    echo "  WARNING: Gatekeeper acceptance is not expected."
fi
echo "  App: $APP_BUNDLE"
echo "  Zip: $ZIP_PATH"
echo "  DMG: $DMG_PATH"
echo "  Source: $SOURCE_DIR"
echo "  Checksums: $CHECKSUM_PATH"
echo "  Architectures: $(lipo -archs "$APP_BUNDLE/Contents/MacOS/DITRenamer")"
echo "=================================================="
