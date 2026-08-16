#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_BUILD_DIR="/tmp/dit-renamer-arri-tests"
mkdir -p "$TEST_BUILD_DIR"

swiftc -parse-as-library -target arm64-apple-macosx14.0 \
    "$PROJECT_ROOT/src_swift/Models.swift" \
    "$PROJECT_ROOT/src_swift/CameraSidecarParsers.swift" \
    "$PROJECT_ROOT/src_swift/MediaScanner.swift" \
    "$PROJECT_ROOT/tests/ARRIMediaScannerTests.swift" \
    -o "$TEST_BUILD_DIR/ARRIMediaScannerTests"

"$TEST_BUILD_DIR/ARRIMediaScannerTests"
