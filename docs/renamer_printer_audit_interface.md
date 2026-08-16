# DIT Renamer Read-Only Audit Interface

DIT Renamer provides a read-only JSON snapshot for the separate DIT Printer application. This is not a control channel: Printer cannot request a rename, unmount, remount, erase, or change Renamer history.

## File locations

```text
~/Library/Application Support/DITRenamer/printer_audit_v1.json
~/Library/Application Support/DITRenamer/printer_audit_v2.json
```

Renamer replaces both snapshots atomically after saving or reloading rename history. Schema v1 remains available for older Printer builds. New Printer builds prefer schema v2 and fall back to v1. These files provide card identity and rename context; neither is proof of Silverstack copy verification.

## Schema v1

```json
{
  "schema_version": 1,
  "generated_at": "2026-08-09T00:00:00Z",
  "records": [
    {
      "rename_id": "00000000-0000-0000-0000-000000000000",
      "renamed_at": "2026-08-09T00:00:00Z",
      "original_name": "Untitled",
      "actual_name": "A001",
      "requested_name": "A001",
      "reuse_count": 2,
      "duplicate_index": 1,
      "volume_uuid": "...",
      "media_uuid": "...",
      "bsd_node": "disk4s1",
      "recorded_mount_path": "/Volumes/Untitled",
      "device_type": "Sony FX3",
      "first_clip_name": "A001C001_240101AA.MP4",
      "last_clip_name": "A001C012_240101AA.MP4",
      "clip_count": 12
    }
  ]
}
```

`recorded_mount_path` is the path recorded before the rename. Printer compares its optional `source_volume_path` with that path and with `actual_name` or `requested_name` as the current mounted volume name. A match only adds read-only context to a label. It does not change a Silverstack job or grant permission to erase a card.

`reuse_count` is optional DIT metadata for label and audit output only. It never changes `actual_name` or `requested_name`, and the key is omitted when the operator leaves reuse recording disabled. `duplicate_index` records an explicit same-camera-ID conflict suffix such as `_1`.

## Schema v2 additions

Schema v2 is a backward-compatible data superset written to `printer_audit_v2.json`. It adds:

```json
{
  "schema_version": 2,
  "records": [
    {
      "total_file_count": 256,
      "used_space": "243.6 GB",
      "file_system": "exfat",
      "is_high_confidence": true,
      "is_unformatted": false,
      "is_empty_card": false,
      "is_photo_only": false,
      "is_unconfigured_camera": false
    }
  ]
}
```

Printer may use these fields for label context and warning badges. It must not treat Renamer confidence or scan flags as Silverstack copy/verify results.
