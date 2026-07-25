#!/bin/bash
# DIT Renamer 一键 macOS 打包与导出脚本
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DIST_DIR="$PROJECT_ROOT/dist"
BUILD_DIR="$PROJECT_ROOT/build"
DOWNLOADS_DIR="$HOME/Downloads"

echo "=================================================="
echo "🎬 开始构建 DIT Renamer V0.1 (macOS 独立应用程序)"
echo "=================================================="

cd "$PROJECT_ROOT"

# 清理历史构建产物
rm -rf "$DIST_DIR" "$BUILD_DIR" "*.spec"

echo "📦 正在使用 PyInstaller 打包 .app ..."
# 使用 PyInstaller 编译，捆绑 web/index.html 及 docs 手册数据文件
pyinstaller --noconfirm \
    --name "dit_renamer_V0.1" \
    --windowed \
    --add-data "src/web/index.html:web" \
    --add-data "docs:docs" \
    --clean \
    "src/app.py"

echo "📑 正在导出并压缩至系统下载文件夹 (~/Downloads) ..."
cp -r "$DIST_DIR/dit_renamer_V0.1.app" "$DOWNLOADS_DIR/"
cd "$DIST_DIR"
rm -f "$DOWNLOADS_DIR/dit_renamer_V0.1.zip"
zip -r -q "$DOWNLOADS_DIR/dit_renamer_V0.1.zip" "dit_renamer_V0.1.app"

echo "✅ 构建完工！已无缝同步至您的下载文件夹："
echo "   👉 App 应用程序: $DOWNLOADS_DIR/dit_renamer_V0.1.app"
echo "   👉 Zip 压缩包:   $DOWNLOADS_DIR/dit_renamer_V0.1.zip"
echo "=================================================="
