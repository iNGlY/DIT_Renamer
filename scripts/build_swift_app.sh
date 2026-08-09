#!/bin/bash
# DIT Renamer Release 1.1 一键编译打包、签名与 DMG 生成脚本
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
RELEASE_DIR="$PROJECT_ROOT/Release"
VERSION="1.1"
APP_NAME="dit_renamer_Release_${VERSION}"
APP_BUNDLE="$RELEASE_DIR/$APP_NAME.app"
DMG_NAME="dit_renamer_Release_${VERSION}.dmg"
DMG_PATH="$RELEASE_DIR/$DMG_NAME"
ZIP_NAME="dit_renamer_Release_${VERSION}.zip"

echo "=================================================="
echo "[BUILD] 开始编译 DIT Renamer Release ${VERSION} 纯原生 App"
echo "=================================================="

# 1. 尝试结束正在运行的进程与清理旧版垃圾
echo "[CLEAN] 正在结束运行进程并清理旧版本..."
killall DITRenamer 2>/dev/null || true
killall "DIT Renamer" 2>/dev/null || true

rm -rf "$RELEASE_DIR"/*

mkdir -p "$RELEASE_DIR"
BUILD_DIR="$PROJECT_ROOT/build_swift"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

cd "$PROJECT_ROOT"

echo "[COMPILING] 正在调用 Apple Swift 编译器 (swiftc) ..."

# 查找所有 swift 源码
SWIFT_FILES=$(find src_swift -name "*.swift")

# 使用 swiftc 编译 macOS 原生 Executable
swiftc -parse-as-library \
    -O \
    -target arm64-apple-macosx14.0 \
    -o "$BUILD_DIR/DITRenamer" \
    $SWIFT_FILES

echo "[BUNDLE] 正在生成 macOS App Bundle 结构与图标 (.app + AppIcon.icns) ..."

mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/DITRenamer" "$APP_BUNDLE/Contents/MacOS/"

if [ -f "$PROJECT_ROOT/AppIcon.icns" ]; then
    cp "$PROJECT_ROOT/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi

# 写入 PList 元数据
cat <<EOF > "$APP_BUNDLE/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>DITRenamer</string>
    <key>CFBundleIdentifier</key>
    <string>com.dit.renamer.release</string>
    <key>CFBundleName</key>
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

echo "[SIGN] 正在清理 Quarantine 属性并实施 ad-hoc 签名 ..."
xattr -cr "$APP_BUNDLE" || true
codesign --force --deep --options runtime --sign - "$APP_BUNDLE"

echo "[ZIP] 正在生成 App Zip 压缩包并彻底清除隔离属性..."
ZIP_PATH="$RELEASE_DIR/$ZIP_NAME"
cd "$RELEASE_DIR"
zip -r -q "$ZIP_NAME" "$APP_NAME.app"
xattr -cr "$ZIP_PATH" || true
cd "$PROJECT_ROOT"

echo "[DMG] 正在生成拖拽安装盘镜像 (.dmg) 并内置【右键双击修复已损坏】工具 ..."
DMG_STAGE="$BUILD_DIR/dmg_stage"
rm -rf "$DMG_STAGE"
mkdir -p "$DMG_STAGE"

cp -R "$APP_BUNDLE" "$DMG_STAGE/DIT Renamer.app"
ln -s /Applications "$DMG_STAGE/Applications"

# 生成内置双击修复脚本 (Fix Damaged App Tool)
FIX_SCRIPT="$DMG_STAGE/右键双击一键修复已损坏.command"
cat <<'EOF' > "$FIX_SCRIPT"
#!/bin/bash
echo "=================================================="
echo "  DIT Renamer macOS 权限与 Gatekeeper 快速修复工具"
echo "=================================================="
echo ""
echo "正在为您解除 macOS 隔离属性 (com.apple.quarantine) ..."
echo ""

APP_PATH="/Applications/DIT Renamer.app"

if [ -d "$APP_PATH" ]; then
    xattr -rd com.apple.quarantine "$APP_PATH" 2>/dev/null || true
    sudo xattr -rd com.apple.quarantine "$APP_PATH" 2>/dev/null || true
    echo "=================================================="
    echo "[成功] 已成功清除隔离属性！"
    echo "现在您可以直接在 Applications 中双击打开 DIT Renamer！"
    echo "=================================================="
else
    echo "=================================================="
    echo "[提示] 未在 /Applications 目录下找到 DIT Renamer.app！"
    echo "请先将 DIT Renamer 拖入 Applications 应用程序文件夹后再运行本修复工具。"
    echo "=================================================="
fi
echo ""
read -p "按回车键退出..."
EOF

chmod +x "$FIX_SCRIPT"

# 生成简单说明文本 README
cat <<'EOF' > "$DMG_STAGE/安装说明与遇到“已损坏”解决方法.txt"
==================================================
🎬 DIT Renamer 拖拽安装与修复指南
==================================================

【第一步：常规安装】
将左侧的 [DIT Renamer.app] 拖入右侧的 [Applications] 文件夹中即可完成安装。

【第二步：如果打开提示“已损坏 / 无法确认开发者”】
这是由于未通过 Mac App Store 下载时 macOS 系统的安全隔离 (Quarantine) 拦截。

解决方法 (二选一)：
方法 A (极速推荐)：
1. 打开应用程序文件夹 (/Applications)。
2. 右键点击 [右键双击一键修复已损坏.command] 并选择“打开”。
3. 提示修复完成后，即可直接正常运行软件！

方法 B (手动终端解除)：
打开 macOS 终端 (Terminal)，粘贴并运行以下指令：
sudo xattr -rd com.apple.quarantine "/Applications/DIT Renamer.app"
按回车输入开机密码即可。

==================================================
EOF

hdiutil create -volname "DIT Renamer ${VERSION}" -srcfolder "$DMG_STAGE" -ov -format UDZO "$DMG_PATH"

echo "[SIGN] 正在对 DMG 镜像签名与重置隔离属性 ..."
xattr -cr "$DMG_PATH" || true
codesign --force --sign - "$DMG_PATH" || true

echo "=================================================="
echo "[SUCCESS] DIT Renamer Release ${VERSION} 打包完毕！"
echo "   - App 应用程序: $APP_BUNDLE"
echo "   - Zip 压缩包:   $RELEASE_DIR/$ZIP_NAME"
echo "   - DMG 安装包:   $DMG_PATH"
echo "   - 已内置【右键双击一键修复已损坏.command】辅助工具！"
echo "=================================================="
