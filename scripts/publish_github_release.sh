#!/bin/bash
# Publishes the validated DIT Renamer 1.1 ad-hoc assets as the latest GitHub release.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
RELEASE_DIR="$PROJECT_ROOT/Release"
VERSION="1.1"
TAG="v1.1.0"
ASSET_BASENAME="dit_renamer_Release_${VERSION}-adhoc-unnotarized"
ZIP_PATH="$RELEASE_DIR/$ASSET_BASENAME.zip"
DMG_PATH="$RELEASE_DIR/$ASSET_BASENAME.dmg"
APP_PATH="$RELEASE_DIR/$ASSET_BASENAME.app"
CHECKSUM_PATH="$RELEASE_DIR/SHA256SUMS.txt"
METADATA_PATH="$RELEASE_DIR/RELEASE_METADATA.txt"
NOTES_PATH="$PROJECT_ROOT/docs/github_release_notes_1.1.md"
LICENSE_PATH="$PROJECT_ROOT/LICENSE"
NOTICE_PATH="$PROJECT_ROOT/NOTICE"

fail() {
    echo "[ERROR] $1" >&2
    exit 1
}

for required in git gh lipo shasum; do
    command -v "$required" >/dev/null 2>&1 || fail "Required command is unavailable: $required"
done

cd "$PROJECT_ROOT"
[[ -z "$(git status --porcelain)" ]] || fail "Commit all source changes before publishing."
gh auth status >/dev/null 2>&1 || fail "GitHub CLI is not authenticated. Run: gh auth login"
git remote get-url origin >/dev/null 2>&1 || fail "Git remote 'origin' is not configured."

for asset in "$ZIP_PATH" "$DMG_PATH" "$APP_PATH" "$CHECKSUM_PATH" "$METADATA_PATH" "$NOTES_PATH" "$LICENSE_PATH" "$NOTICE_PATH"; do
    [[ -e "$asset" ]] || fail "Missing release asset: $asset"
done

lipo "$APP_PATH/Contents/MacOS/DITRenamer" -verify_arch arm64 x86_64
(
    cd "$RELEASE_DIR"
    shasum -a 256 -c "$(basename "$CHECKSUM_PATH")"
)

release_commit="$(sed -n 's/^commit=//p' "$METADATA_PATH")"
[[ "$release_commit" == "$(git rev-parse HEAD)" ]] || fail "Release assets were not built from the current HEAD."

current_branch="$(git branch --show-current)"
[[ -n "$current_branch" ]] || fail "Publishing from a detached HEAD is not supported."

if gh release view "$TAG" >/dev/null 2>&1; then
    fail "GitHub release $TAG already exists; review it before uploading replacement assets."
fi

git push -u origin "$current_branch"

if git rev-parse "$TAG" >/dev/null 2>&1; then
    [[ "$(git rev-list -n 1 "$TAG")" == "$(git rev-parse HEAD)" ]] || fail "Existing tag $TAG does not point to HEAD."
else
    git tag -a "$TAG" -m "DIT Renamer 1.1"
fi
git push origin "$TAG"

gh release create "$TAG" \
    "$DMG_PATH" \
    "$ZIP_PATH" \
    "$CHECKSUM_PATH" \
    "$LICENSE_PATH" \
    "$NOTICE_PATH" \
    --title "DIT Renamer 1.1" \
    --notes-file "$NOTES_PATH" \
    --latest \
    --verify-tag

echo "[SUCCESS] GitHub latest release $TAG published."
