#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_BUILD_DIR="/tmp/dit-renamer-dji-auto-mount-tests"
mkdir -p "$TEST_BUILD_DIR"

swiftc -parse-as-library -target arm64-apple-macosx14.0 \
    "$PROJECT_ROOT/src_swift/Models/DJIAutoMountPolicy.swift" \
    "$PROJECT_ROOT/src_swift/Models/DJIAutoMounter.swift" \
    "$PROJECT_ROOT/tests/DJIAutoMounterTests.swift" \
    -o "$TEST_BUILD_DIR/DJIAutoMounterTests"

"$TEST_BUILD_DIR/DJIAutoMounterTests"
