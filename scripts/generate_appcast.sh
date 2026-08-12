#!/bin/bash
# Generates the signed Sparkle appcast from release ZIP/DMG archives.
set -euo pipefail
shopt -s nullglob

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
VERSION="${DIT_RENAMER_VERSION:-1.1.1}"
UPDATE_DIR="${1:-$PROJECT_ROOT/Release}"
APPCAST_PATH="${DIT_RENAMER_APPCAST_PATH:-$PROJECT_ROOT/docs/appcast.xml}"
DOWNLOAD_PREFIX="${DIT_RENAMER_DOWNLOAD_URL_PREFIX:-https://github.com/iNGlY/DIT_Renamer/releases/download/v${VERSION}/}"
ED_KEY_FILE="${DIT_RENAMER_ED_KEY_FILE:-}"

fail() {
    echo "[ERROR] $1" >&2
    exit 1
}

[[ -d "$UPDATE_DIR" ]] || fail "Update archive directory does not exist: $UPDATE_DIR"
SPARKLE_ROOT="$(bash "$SCRIPT_DIR/bootstrap_sparkle.sh")"
[[ -x "$SPARKLE_ROOT/bin/generate_appcast" ]] || fail "Sparkle generate_appcast is unavailable."

SOURCE_DIR="$UPDATE_DIR"
STAGING_DIR=""
ZIP_ARCHIVES=("$UPDATE_DIR"/*.zip)
DMG_ARCHIVES=("$UPDATE_DIR"/*.dmg)
[[ ${#ZIP_ARCHIVES[@]} -gt 0 ]] || fail "No ZIP update archive was found in: $UPDATE_DIR"
if [[ ${#ZIP_ARCHIVES[@]} -gt 0 && ${#DMG_ARCHIVES[@]} -gt 0 ]]; then
    STAGING_DIR="$(mktemp -d /tmp/dit-renamer-appcast.XXXXXX)"
    trap 'rm -rf "$STAGING_DIR"' EXIT
    for archive in "${ZIP_ARCHIVES[@]}"; do
        [[ -f "$archive" ]] || continue
        cp "$archive" "$STAGING_DIR/"
        base="${archive%.zip}"
        for notes in "$base.html" "$base.md" "$base.txt"; do
            [[ -f "$notes" ]] && cp "$notes" "$STAGING_DIR/"
        done
    done
    SOURCE_DIR="$STAGING_DIR"
fi

echo "[APPCAST] Generating signed appcast for DIT Renamer $VERSION..."
GENERATE_ARGS=()
if [[ -n "$ED_KEY_FILE" ]]; then
    [[ -f "$ED_KEY_FILE" ]] || fail "EdDSA key file does not exist: $ED_KEY_FILE"
    GENERATE_ARGS+=(--ed-key-file "$ED_KEY_FILE")
fi
GENERATE_ARGS+=(
    --download-url-prefix "$DOWNLOAD_PREFIX"
    --link "https://github.com/iNGlY/DIT_Renamer/releases/latest"
    --embed-release-notes
    --maximum-deltas 0
    -o "$APPCAST_PATH"
    "$SOURCE_DIR"
)

"$SPARKLE_ROOT/bin/generate_appcast" \
    "${GENERATE_ARGS[@]}"

echo "[SUCCESS] Appcast generated: $APPCAST_PATH"
