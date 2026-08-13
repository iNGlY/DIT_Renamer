#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_BUILD_DIR="/tmp/dit-renamer-audit-metadata-tests"
mkdir -p "$TEST_BUILD_DIR"

swiftc -parse-as-library -target arm64-apple-macosx14.0 \
    "$PROJECT_ROOT/src_swift/Models.swift" \
    "$PROJECT_ROOT/src_swift/Models/RenameAuditFormatting.swift" \
    "$PROJECT_ROOT/src_swift/Models/PrinterAuditExport.swift" \
    "$PROJECT_ROOT/tests/RenameAuditMetadataTests.swift" \
    -o "$TEST_BUILD_DIR/RenameAuditMetadataTests"

"$TEST_BUILD_DIR/RenameAuditMetadataTests"
