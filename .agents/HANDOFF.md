# Current Agent Handoff

## State

- Owner: Codex
- Branch: `codex/swift-1.1-hardening`
- Status: Swift 1.1 integration committed as `2c9f72d`; DIT Printer remains a separately built extension and is not included in the 1.1 app package
- Baseline: `58618e3` (`[codex] record collaboration baseline`)

## Working agreement

- Existing application changes are intentional working material and must be
  preserved.
- `Release/`, `build_swift/`, `build/`, and `.venv` are local/generated assets;
  do not use them as source-of-truth inputs for code changes.
- Before another agent edits, it should read `AGENTS.md`, this file, and the
  latest `.agents/CHANGELOG.md` entry.

## Validation and known risks

- Latest validation: Swift typecheck, both build-script syntax checks, Renamer audit Reader fixture, TSPL label smoke test, Printer codesign verification, `git diff --check`, and 1.1 app/zip/DMG build with codesign verification passed.
- Current task changes: `MainDetailView.swift` exposes a manual toggle for retaining a detected media suffix in the suggested volume name; `VolumeMonitor.swift` excludes Apple Disk Image Media by disk metadata and `SettingsView.swift` shows the locked rule. Renamer now performs a forced unmount and mount only after the same BSD node and UUID pass the rename preflight, then verifies the remounted UUID, name, and mount point before reporting success. Sony model detection reads bounded XML/XMP sidecars first and displays the explicit model (for example `ILME-FX30 -> FX30`, `ILCE-7M4 -> A7M4`); only absent XML/XMP metadata may trigger the optional single-file exiftool fallback. Missing exiftool produces a manual-install banner and never changes naming rules. `ParaShootPDFGenerator.swift` requires the active app language for every export, localizes the report badge/document language/generated timestamp, and includes association detail only when selected in the export panel. `ParaShootParser.swift` reads active plus numeric rotated logs, classifies `missingFiles: 0` as passed, and marks source-path matches as high confidence.
- Separate Printer extension: `src_printer/` is not part of the 1.1 app package. It reads the versioned, atomically written Renamer audit snapshot at `~/Library/Application Support/DITRenamer/printer_audit_v1.json` only to add label context. The interface is documented in `docs/renamer_printer_audit_interface.md`; it cannot trigger Renamer operations.
- Known erase risk: No physical card has been erased or restored in this work. A disposable-card acceptance test must verify the exact Silverstack resource order and ParaShoot behavior before enabling the Copy Job Post Step on a live workflow.
- Known model-detection risk: No real Sony card is mounted. Validate Sony XML/XMP location and exiftool output on representative media from the camera generations used in production; model metadata is display/audit-only and does not alter rename confidence or volume naming.

## Next handoff

Next agent may edit and test on this task branch. Do not merge into `main` until the real-card remount acceptance test and remaining field-safety review items are explicitly confirmed.
