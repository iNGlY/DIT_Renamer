#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_BUILD_DIR="/tmp/dit-renamer-menu-bar-ignore-tests"
mkdir -p "$TEST_BUILD_DIR"

SOURCES=("$PROJECT_ROOT/src_swift/Models.swift")
FILTER_SOURCE="$PROJECT_ROOT/src_swift/Models/MenuBarVolumeFilter.swift"
if [[ -f "$FILTER_SOURCE" ]]; then
    SOURCES+=("$FILTER_SOURCE")
fi

swiftc -parse-as-library -target arm64-apple-macosx14.0 \
    "${SOURCES[@]}" \
    "$PROJECT_ROOT/tests/MenuBarIgnoredVolumeTests.swift" \
    -o "$TEST_BUILD_DIR/MenuBarIgnoredVolumeTests"

"$TEST_BUILD_DIR/MenuBarIgnoredVolumeTests"
