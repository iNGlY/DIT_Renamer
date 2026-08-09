# Current Agent Handoff

## State

- Owner: Codex
- Branch: `codex/swift-1.1-hardening`
- Status: Swift 1.1 integration committed as `2c9f72d`; universal Developer ID/notarization release pipeline committed as `f13014a`; accurate bilingual About content and ARRI/CODEX CLI research committed as `2270cf4`; DIT Printer remains a separately built extension and is not included in the 1.1 app package
- Baseline: `58618e3` (`[codex] record collaboration baseline`)

## Working agreement

- Existing application changes are intentional working material and must be
  preserved.
- `Release/`, `build_swift/`, `build/`, and `.venv` are local/generated assets;
  do not use them as source-of-truth inputs for code changes.
- Before another agent edits, it should read `AGENTS.md`, this file, and the
  latest `.agents/CHANGELOG.md` entry.

## Validation and known risks

- Latest validation: The revised About view passed Swift typecheck and optimized executable compilation for `arm64` and `x86_64`; macOS Bash 3.2 syntax check and `git diff --check` passed. ARRI Reference Tool official sources and the signed universal 1.0.0 package were inspected, and `art-cmd --help` confirmed no HDE output codec or size-only estimate option. Developer ID signing, Apple notarization, stapling, and successful Gatekeeper acceptance were not run because this Mac has no valid signing identity and no configured notarytool profile.
- Current task changes: `MainDetailView.swift` exposes a manual toggle for retaining a detected media suffix in the suggested volume name; `VolumeMonitor.swift` excludes Apple Disk Image Media by disk metadata and `SettingsView.swift` shows the locked rule. Renamer now performs a forced unmount and mount only after the same BSD node and UUID pass the rename preflight, then verifies the remounted UUID, name, and mount point before reporting success. Sony model detection reads bounded XML/XMP sidecars first and displays the explicit model (for example `ILME-FX30 -> FX30`, `ILCE-7M4 -> A7M4`); only absent XML/XMP metadata may trigger the optional single-file exiftool fallback. Missing exiftool produces a manual-install banner and never changes naming rules. `ParaShootPDFGenerator.swift` requires the active app language for every export, localizes the report badge/document language/generated timestamp, and includes association detail only when selected in the export panel. `ParaShootParser.swift` reads active plus numeric rotated logs, classifies `missingFiles: 0` as passed, and marks source-path matches as high confidence.
- Separate Printer extension: `src_printer/` is not part of the 1.1 app package. It reads the versioned, atomically written Renamer audit snapshot at `~/Library/Application Support/DITRenamer/printer_audit_v1.json` only to add label context. The interface is documented in `docs/renamer_printer_audit_interface.md`; it cannot trigger Renamer operations.
- Known erase risk: No physical card has been erased or restored in this work. A disposable-card acceptance test must verify the exact Silverstack resource order and ParaShoot behavior before enabling the Copy Job Post Step on a live workflow.
- Known model-detection risk: No real Sony card is mounted. Validate Sony XML/XMP location and exiftool output on representative media from the camera generations used in production; model metadata is display/audit-only and does not alter rename confidence or volume naming.
- Known HDE risk: Public ARRI sources identify `art-cmd` as ARRI Reference Tool CMD, not CODEX Device Manager CLI. They do not document a public `codex-hde` command or size-only HDE estimate mode. `MediaScanner.swift` still probes speculative `codex-hde` paths and `MainDetailView.swift` still labels the fixed 60% estimate as an official model; remove or relabel this only after user approval.
- Known release risk: `Release/` still contains the previous arm64-only ad-hoc build and its DMG is rejected by Gatekeeper. Do not distribute it as the 1.1 notarized release. Install a `Developer ID Application` certificate, store a notarytool keychain profile, then run `scripts/build_swift_app.sh`; the script only replaces `Release/` after App and DMG signing, notarization, stapling, and `spctl` validation all succeed.

## Next handoff

Next agent may edit and test on this task branch. Do not merge into `main` until the real-card remount acceptance test and remaining field-safety review items are explicitly confirmed. Obtain user approval before removing the speculative `codex-hde` probe or relabeling the HDE result card.
