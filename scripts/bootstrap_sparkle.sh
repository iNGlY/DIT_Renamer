#!/bin/bash
# Downloads and verifies the pinned Sparkle binary used by the direct swiftc build.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SPARKLE_VERSION="2.9.5"
SPARKLE_ARCHIVE="Sparkle-for-Swift-Package-Manager.zip"
SPARKLE_URL="https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/${SPARKLE_ARCHIVE}"
SPARKLE_SHA256="34b9b2071f3de0012eca3faa3a9290bb94e62131e9a74f6dc91514a000097a6c"
DEPENDENCY_ROOT="$PROJECT_ROOT/.deps/sparkle"
INSTALL_ROOT="$DEPENDENCY_ROOT/Sparkle-$SPARKLE_VERSION"
FRAMEWORK_PATH="$INSTALL_ROOT/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"

fail() {
    echo "[ERROR] $1" >&2
    exit 1
}

for required in curl ditto shasum; do
    command -v "$required" >/dev/null 2>&1 || fail "Required command is unavailable: $required"
done

if [[ -d "$FRAMEWORK_PATH" && -x "$INSTALL_ROOT/bin/generate_appcast" ]]; then
    printf '%s\n' "$INSTALL_ROOT"
    exit 0
fi

mkdir -p "$DEPENDENCY_ROOT"
ARCHIVE_PATH="$DEPENDENCY_ROOT/$SPARKLE_ARCHIVE"
if [[ ! -f "$ARCHIVE_PATH" ]]; then
    echo "[DOWNLOAD] Sparkle $SPARKLE_VERSION" >&2
    curl --fail --location --retry 3 --output "$ARCHIVE_PATH" "$SPARKLE_URL"
fi

printf '%s  %s\n' "$SPARKLE_SHA256" "$ARCHIVE_PATH" | shasum --algorithm 256 --check --strict - \
    >&2 || fail "Sparkle archive checksum mismatch: $ARCHIVE_PATH"

if [[ -e "$INSTALL_ROOT" ]]; then
    fail "Sparkle dependency is incomplete at $INSTALL_ROOT; remove only this generated directory and retry."
fi

STAGING_ROOT="$(mktemp -d "$DEPENDENCY_ROOT/.staging.XXXXXX")"
ditto -x -k "$ARCHIVE_PATH" "$STAGING_ROOT"
mv "$STAGING_ROOT" "$INSTALL_ROOT"

[[ -d "$FRAMEWORK_PATH" ]] || fail "Sparkle framework was not found after extraction."
[[ -x "$INSTALL_ROOT/bin/generate_appcast" ]] || fail "Sparkle tools were not found after extraction."
printf '%s\n' "$INSTALL_ROOT"
