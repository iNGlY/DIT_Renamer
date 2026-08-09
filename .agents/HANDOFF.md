# Current Agent Handoff

## State

- Owner: Codex
- Branch: `codex/swift-1.1-hardening`
- Status: Swift 1.1 integration committed as `2c9f72d`; universal Developer ID/notarization release pipeline committed as `f13014a`; accurate bilingual About content and ARRI/CODEX CLI research committed as `2270cf4`; explicit ad-hoc GitHub prerelease flow committed as `eca1ba1`; Sparkle 2.9.5 1.1.1 update flow committed as `b28682e`; bilingual public install documentation and changelog committed as `5107187`; DIT Printer remains a separately built extension and is not included in the 1.1 app package
- Baseline: `58618e3` (`[codex] record collaboration baseline`)

## Working agreement

- Existing application changes are intentional working material and must be
  preserved.
- `Release/`, `build_swift/`, `build/`, and `.venv` are local/generated assets;
  do not use them as source-of-truth inputs for code changes.
- Before another agent edits, it should read `AGENTS.md`, this file, and the
  latest `.agents/CHANGELOG.md` entry.

## Validation and known risks

- Latest validation: Explicit `adhoc` mode produced App/ZIP/DMG assets containing a valid ad-hoc signed `arm64 + x86_64` executable. App copies from the build, ZIP, and mounted DMG passed signature and architecture verification; SHA-256 checks passed; the DMG warning was inspected; Gatekeeper rejection was confirmed as expected. The default mode still requires Developer ID signing, Apple notarization, stapling, and successful Gatekeeper acceptance.
- 1.1.1 update validation: `/Users/Do2n4c7rY/Downloads/DIT_Renamer/Release/` contains the current universal `1.1.1` ad-hoc App/ZIP/DMG. Sparkle nested helpers and the App passed strict signature verification, the App contains both architectures and the expected Sparkle keys, release checksums passed, and a protected EdDSA key generated a valid single-ZIP appcast entry. `docs/appcast.xml` remains an empty feed until the corresponding GitHub Release asset is public.
- Documentation/release regression: The public README and changelog are bilingual and include first-install instructions. A mounted 1.1.1 DMG confirmed `Applications -> /Applications`; the main App launch smoke test did not crash; DIT Printer build/signature, TSPL rendering, and Renamer audit fixture tests passed. No physical media operation was performed.
- Current task changes: `MainDetailView.swift` exposes a manual toggle for retaining a detected media suffix in the suggested volume name; `VolumeMonitor.swift` excludes Apple Disk Image Media by disk metadata and `SettingsView.swift` shows the locked rule. Renamer now performs a forced unmount and mount only after the same BSD node and UUID pass the rename preflight, then verifies the remounted UUID, name, and mount point before reporting success. Sony model detection reads bounded XML/XMP sidecars first and displays the explicit model (for example `ILME-FX30 -> FX30`, `ILCE-7M4 -> A7M4`); only absent XML/XMP metadata may trigger the optional single-file exiftool fallback. Missing exiftool produces a manual-install banner and never changes naming rules. `ParaShootPDFGenerator.swift` requires the active app language for every export, localizes the report badge/document language/generated timestamp, and includes association detail only when selected in the export panel. `ParaShootParser.swift` reads active plus numeric rotated logs, classifies `missingFiles: 0` as passed, and marks source-path matches as high confidence.
- Separate Printer extension: `src_printer/` is not part of the 1.1 app package. It reads the versioned, atomically written Renamer audit snapshot at `~/Library/Application Support/DITRenamer/printer_audit_v1.json` only to add label context. The interface is documented in `docs/renamer_printer_audit_interface.md`; it cannot trigger Renamer operations.
- Known erase risk: No physical card has been erased or restored in this work. A disposable-card acceptance test must verify the exact Silverstack resource order and ParaShoot behavior before enabling the Copy Job Post Step on a live workflow.
- Known model-detection risk: No real Sony card is mounted. Validate Sony XML/XMP location and exiftool output on representative media from the camera generations used in production; model metadata is display/audit-only and does not alter rename confidence or volume naming.
- Known HDE risk: Public ARRI sources identify `art-cmd` as ARRI Reference Tool CMD, not CODEX Device Manager CLI. They do not document a public `codex-hde` command or size-only HDE estimate mode. `MediaScanner.swift` still probes speculative `codex-hde` paths and `MainDetailView.swift` still labels the fixed 60% estimate as an official model; remove or relabel this only after user approval.
- Known release risk: `Release/` now contains a universal ad-hoc build explicitly labeled `adhoc-unnotarized`; Gatekeeper rejection is expected, so it is suitable only for a clearly warned GitHub Pre-release or internal test. For a stable release, install a `Developer ID Application` certificate, store a notarytool keychain profile, then run the default `scripts/build_swift_app.sh`; strict mode only replaces `Release/` after signing, notarization, stapling, and `spctl` validation all succeed.
- Known GitHub release state: Public repository `https://github.com/iNGlY/DIT_Renamer` uses `codex/swift-1.1-hardening` as its default branch. Annotated tag `v1.1.0` resolves to release commit `11227ce`, and `https://github.com/iNGlY/DIT_Renamer/releases/latest` resolves to the published Latest Release with DMG, ZIP, SHA-256, LICENSE, and NOTICE assets. GitHub CLI 2.97.0 is authenticated as `iNGlY`.
- Licensing state: Default branch commit `a89e5a6` applies Apache License 2.0 with `Copyright 2026 DIT247` and a NOTICE requiring retention of DIT247 attribution. The current GitHub release includes LICENSE and NOTICE assets and updated notes. The older immutable `v1.1.0` tag source archive itself predates the license commit; do not move the published tag, and ensure the next release tag includes `a89e5a6` or later.

## Next handoff

Next agent may edit and test on this task branch. Do not merge into `main` until the real-card remount acceptance test and remaining field-safety review items are explicitly confirmed. Obtain user approval before removing the speculative `codex-hde` probe or relabeling the HDE result card. `v1.1.0` is now Latest Release by user request, but remains ad-hoc signed and unnotarized. Use the new `v1.1.1` tag rather than rewriting `v1.1.0` so the next tag source archive includes the Apache-2.0 license and current documentation. GitHub Pages configuration, actual Release publication, and end-to-end old-version-to-new-version Sparkle installation remain external acceptance steps.
