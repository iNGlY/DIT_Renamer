#!/bin/bash
# Builds the experimental standalone DIT Printer app and its Silverstack bridge.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_ROOT/build_printer"
APP_BUNDLE="$BUILD_DIR/DIT Printer.app"
APP_SOURCES=(
    "$PROJECT_ROOT/src_printer/Shared/PrinterJob.swift"
    "$PROJECT_ROOT/src_printer/Shared/RenamerAuditReader.swift"
    "$PROJECT_ROOT/src_printer/LabelTemplateStore.swift"
    "$PROJECT_ROOT/src_printer/CUPSPrinter.swift"
    "$PROJECT_ROOT/src_printer/DITPrinterApp.swift"
)

mkdir -p "$BUILD_DIR" "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Helpers"
export CLANG_MODULE_CACHE_PATH="$BUILD_DIR/module-cache"

swiftc -parse-as-library -O -target arm64-apple-macosx14.0 \
    -o "$APP_BUNDLE/Contents/MacOS/DITPrinter" \
    "${APP_SOURCES[@]}"

swiftc -O -target arm64-apple-macosx14.0 \
    -o "$APP_BUNDLE/Contents/Helpers/DITPrinterBridge" \
    "$PROJECT_ROOT/src_printer/Shared/PrinterJob.swift" \
    "$PROJECT_ROOT/src_printer/Shared/RenamerAuditReader.swift" \
    "$PROJECT_ROOT/src_printer/DITPrinterBridge.swift"

swiftc -parse-as-library -O -target arm64-apple-macosx14.0 \
    -o "$APP_BUNDLE/Contents/Helpers/ParaShootEraseBridge" \
    "$PROJECT_ROOT/src_printer/ParaShootEraseBridge.swift"

cp "$PROJECT_ROOT/src_printer/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
codesign --force --deep --sign - "$APP_BUNDLE"

echo "Built: $APP_BUNDLE"
echo "Bridge: $APP_BUNDLE/Contents/Helpers/DITPrinterBridge"
echo "Erase bridge: $APP_BUNDLE/Contents/Helpers/ParaShootEraseBridge"
