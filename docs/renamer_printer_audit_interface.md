# DIT Renamer Read-Only Audit Interface

DIT Renamer provides a read-only JSON snapshot for the separate DIT Printer application. This is not a control channel: Printer cannot request a rename, unmount, remount, erase, or change Renamer history.

## File location

```text
~/Library/Application Support/DITRenamer/printer_audit_v1.json
```

Renamer replaces the snapshot atomically after saving or reloading rename history. The file provides label context and an operational record; it is not proof of Silverstack copy verification.

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
