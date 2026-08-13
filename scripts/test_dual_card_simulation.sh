#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SIMULATION_DIR="$(mktemp -d /tmp/dit-renamer-dual-card.XXXXXX)"
BASE_IMAGE="$SIMULATION_DIR/card-a.dmg"
CLONE_IMAGE="$SIMULATION_DIR/card-b.dmg"
ATTACHED_DEVICES=()

cleanup() {
    for device in "${ATTACHED_DEVICES[@]}"; do
        [[ -n "$device" ]] || continue
        hdiutil detach "$device" >/dev/null 2>&1 || true
    done
    case "$SIMULATION_DIR" in
        /tmp/dit-renamer-dual-card.*) /bin/rm -rf -- "$SIMULATION_DIR" ;;
        *) echo "Refusing to remove unexpected simulation path: $SIMULATION_DIR" >&2 ;;
    esac
}
trap cleanup EXIT

partition_device_for_image() {
    local image="$1"
    local output
    output="$(hdiutil attach -nobrowse "$image")"
    printf '%s\n' "$output" >&2
    printf '%s\n' "$output" | awk '$1 ~ /^\/dev\/disk[0-9]+s[0-9]+$/ { device=$1 } END { print device }'
}

plist_value() {
    local device="$1"
    local key="$2"
    diskutil info -plist "$device" | plutil -extract "$key" raw -o - - 2>/dev/null || true
}

echo "[SIMULATION] Creating two disposable cloned exFAT card images..."
hdiutil create -size 64m -fs ExFAT -volname Untitled "$BASE_IMAGE" >/dev/null

seed_device="$(partition_device_for_image "$BASE_IMAGE")"
[[ -n "$seed_device" ]] || { echo "Could not attach seed image." >&2; exit 1; }
ATTACHED_DEVICES+=("$seed_device")
seed_mount="$(plist_value "$seed_device" MountPoint)"
[[ -n "$seed_mount" && "$seed_mount" == /Volumes/* ]] || { echo "Invalid seed mount point: $seed_mount" >&2; exit 1; }
mkdir -p "$seed_mount/PRIVATE/M4ROOT/CLIP" "$seed_mount/PRIVATE/M4ROOT/GENERAL"
printf '<ModelName>ILME-FX3</ModelName>\n' > "$seed_mount/PRIVATE/M4ROOT/GENERAL/M01.XML"
printf 'fixture-a1\n' > "$seed_mount/PRIVATE/M4ROOT/CLIP/A247C001_260813AA.MP4"
printf 'fixture-a2\n' > "$seed_mount/PRIVATE/M4ROOT/CLIP/A247C002_260813AA.MP4"
hdiutil detach "$seed_device" >/dev/null
ATTACHED_DEVICES=()
cp "$BASE_IMAGE" "$CLONE_IMAGE"

device_a="$(partition_device_for_image "$BASE_IMAGE")"
[[ -n "$device_a" ]] || { echo "Could not attach card A image." >&2; exit 1; }
ATTACHED_DEVICES+=("$device_a")
device_b="$(partition_device_for_image "$CLONE_IMAGE")"
[[ -n "$device_b" ]] || { echo "Could not attach card B image." >&2; exit 1; }
ATTACHED_DEVICES+=("$device_b")

mount_a="$(plist_value "$device_a" MountPoint)"
mount_b="$(plist_value "$device_b" MountPoint)"
uuid_a="$(plist_value "$device_a" VolumeUUID)"
uuid_b="$(plist_value "$device_b" VolumeUUID)"
media_a="$(plist_value "$device_a" MediaUUID)"
media_b="$(plist_value "$device_b" MediaUUID)"
name_a="$(plist_value "$device_a" VolumeName)"
name_b="$(plist_value "$device_b" VolumeName)"

[[ -n "$mount_a" && -n "$mount_b" && "$mount_a" != "$mount_b" ]]
[[ "$mount_a" == /Volumes/* && "$mount_b" == /Volumes/* ]]
[[ "$uuid_a" == "$uuid_b" ]]
[[ "$name_a" == "Untitled" && "$name_b" == "Untitled" ]]

find "$mount_b/PRIVATE/M4ROOT/CLIP" -type f -delete
printf 'fixture-b1\n' > "$mount_b/PRIVATE/M4ROOT/CLIP/B101C001_260813BB.MP4"
printf 'fixture-b2\n' > "$mount_b/PRIVATE/M4ROOT/CLIP/B101C002_260813BB.MP4"

TEST_BUILD_DIR="$SIMULATION_DIR/build"
mkdir -p "$TEST_BUILD_DIR"
swiftc -parse-as-library -target arm64-apple-macosx14.0 \
    "$PROJECT_ROOT/src_swift/Models.swift" \
    "$PROJECT_ROOT/src_swift/MediaScanner.swift" \
    "$PROJECT_ROOT/src_swift/RenamerEngine.swift" \
    "$PROJECT_ROOT/tests/DualCardIntegrationProbe.swift" \
    -o "$TEST_BUILD_DIR/DualCardIntegrationProbe"

"$TEST_BUILD_DIR/DualCardIntegrationProbe" \
    "$mount_a" "${device_a#/dev/}" "$uuid_a" "${media_a:--}" \
    "$mount_b" "${device_b#/dev/}" "$uuid_b" "${media_b:--}"

[[ "$(plist_value "$device_a" VolumeName)" == "A247" ]]
[[ "$(plist_value "$device_b" VolumeName)" == "B101" ]]
[[ "$(plist_value "$device_a" VolumeUUID)" == "$uuid_a" ]]
[[ "$(plist_value "$device_b" VolumeUUID)" == "$uuid_b" ]]

echo "Dual-card same-UUID rename/remount simulation: PASS"
