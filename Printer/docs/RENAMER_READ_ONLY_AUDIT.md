# DIT Renamer Read-Only Audit Contract

DIT Printer may read this optional JSON snapshot:

```text
~/Library/Application Support/DITRenamer/printer_audit_v1.json
```

The snapshot is an optional source of label context. It is not evidence of a
Silverstack verification result and it is not a bidirectional integration.
Printer must never write this file or use it to ask DIT Renamer to rename,
mount, eject, verify, erase, or alter history.

Schema version `1` contains `records` with values such as `rename_id`,
`renamed_at`, `actual_name`, `requested_name`, `volume_uuid`,
`recorded_mount_path`, `device_type`, and `last_clip_name`. Printer matches an
optional Silverstack `source_volume_path` against the recorded mount path or
volume-name fields, then shows the matching data as read-only context.
