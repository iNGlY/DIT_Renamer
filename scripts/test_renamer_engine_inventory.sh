#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_BUILD_DIR="/tmp/dit-renamer-engine-inventory-tests"
mkdir -p "$TEST_BUILD_DIR"

swiftc -parse-as-library -target arm64-apple-macosx14.0 \
    "$PROJECT_ROOT/src_swift/RenamerEngine.swift" \
    "$PROJECT_ROOT/tests/RenamerEngineInventoryTests.swift" \
    -o "$TEST_BUILD_DIR/RenamerEngineInventoryTests"

"$TEST_BUILD_DIR/RenamerEngineInventoryTests"
