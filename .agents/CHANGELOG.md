# Agent Change Log

This log records changes made by Codex, Antigravity, and other agents. Git is
the source of truth for the exact diff; this file records intent, validation,
and handoff context.

## Entry format

```markdown
### YYYY-MM-DD — [agent] short summary
- Commit: `<hash>`
- Branch: `<branch>`
- Changed: `<paths or areas>`
- Validation: `<commands and result>`
- Follow-up/risk: `<none or details>`
```

### 2026-08-08 — [codex] Establish collaboration contract
- Commit: `f8d26d4`
- Branch: `main`
- Changed: `AGENTS.md`, `.agents/CHANGELOG.md`, `.agents/HANDOFF.md`, `.gitignore`
- Validation: `python3 -m py_compile src/app.py`; working tree clean after commit
- Follow-up/risk: Existing application work was present before this entry and
  is being preserved in the baseline commit.

### 2026-08-09 — [codex] Research public DIT skills and tools
- Commit: `uncommitted`
- Branch: `codex/swift-1.1-hardening`
- Changed: `docs/research_dit_skills.md`
- Validation: Public web search plus GitHub repository/file inspection; no DIT-specific installable Agent Skill was found.
- Follow-up/risk: Open-source DIT utilities require independent code, license, and production-safety review before adoption.

### 2026-08-09 — [codex] Research GP-M325F Silverstack Lua label printing
- Commit: `uncommitted`
- Branch: `codex/swift-1.1-hardening`
- Changed: `docs/research_gp_m325f_silverstack_lua_label.md`
- Validation: Pomfort scripting repository/API and workflow docs, plus Gprinter GP-M325F product/operation docs inspected; `git diff --check` passed.
- Follow-up/risk: Exact GP-M325F macOS queue/serial behavior and label dimensions still require testing with the physical printer.

### 2026-08-09 — [codex] Analyze DIT-Agent camera detection
- Commit: `uncommitted`
- Branch: `codex/swift-1.1-hardening`
- Changed: `docs/research_dit_agent_camera_detection.md`
- Validation: GitHub README, SKILL.md, server.py, and media_info.py inspected; `git diff --check` passed.
- Follow-up/risk: Upstream camera detection has nested-card and path-argument limitations; do not treat its camera label as authoritative without a local fix and DIT confirmation.

### 2026-08-09 — [codex] Add manual media suffix selection
- Commit: `uncommitted`
- Branch: `codex/swift-1.1-hardening`
- Changed: `src_swift/Views/MainDetailView.swift`
- Validation: `swiftc -typecheck -target arm64-apple-macosx14.0 $(find src_swift -name '*.swift' -print)`; `bash -n scripts/build_swift_app.sh`; `git diff --check`; `./scripts/build_swift_app.sh` all passed. A temporary DMG was mounted and confirmed `BusProtocol=Disk Image`, then detached.
- Follow-up/risk: DJI suffix is retained by default but can be disabled for the suggested volume name; exFAT/FAT 11-character enforcement remains in `RenamerEngine`.

### 2026-08-09 — [codex] Exclude Apple Disk Image Media
- Commit: `uncommitted`
- Branch: `codex/swift-1.1-hardening`
- Changed: `src_swift/VolumeMonitor.swift`, `src_swift/Views/SettingsView.swift`, `docs/hardware_dit_knowledge_base.md`
- Validation: `swiftc -typecheck -target arm64-apple-macosx14.0 $(find src_swift -name '*.swift' -print)`; `bash -n scripts/build_swift_app.sh`; `git diff --check`; `./scripts/build_swift_app.sh` all passed.
- Follow-up/risk: Mounted DMG/sparse image volumes are excluded using `MediaName`/`BusProtocol` metadata and cannot be re-enabled from settings.

### 2026-08-09 — [codex] Bind PDF language to the application language
- Commit: `uncommitted`
- Branch: `codex/swift-1.1-hardening`
- Changed: `src_swift/ParaShootPDFGenerator.swift`
- Validation: `swiftc -typecheck -target arm64-apple-macosx14.0 $(find src_swift -name '*.swift' -print)`; `bash -n scripts/build_swift_app.sh`; `git diff --check`; `./scripts/build_swift_app.sh` all passed.
- Follow-up/risk: Volume labels, device names, and clip filenames remain source data and are intentionally not translated.

### 2026-08-09 — [codex] Classify zero-missing verification and gate PDF association detail
- Commit: `uncommitted`
- Branch: `codex/swift-1.1-hardening`
- Changed: `src_swift/ParaShootParser.swift`, `src_swift/ParaShootPDFGenerator.swift`, `src_swift/Views/ParaShootAuditView.swift`, `src_swift/Views/RightInspectorView.swift`
- Validation: `swiftc -typecheck -target arm64-apple-macosx14.0 $(find src_swift -name '*.swift' -print)`; parsed local active and rotated ParaShoot logs (`events=442`, `passed=307`, `highConfidence=385`); `bash -n scripts/build_swift_app.sh`; `git diff --check`; `./scripts/build_swift_app.sh` all passed.
- Follow-up/risk: A high-confidence association requires a matching logged source path and erase path. Legacy unscoped `CheckResult` lines retain their pass/warning status but are never reported as high confidence.

### 2026-08-09 — [codex] Add DIT Printer and ParaShoot Verify erase bridge
- Commit: `uncommitted`
- Branch: `codex/swift-1.1-hardening`
- Changed: `src_printer/`, `scripts/build_dit_printer.sh`, `docs/dit_printer_silverstack_setup.md`, `docs/DIT_Printer_中文部署教程.md`, `README.md`, `.gitignore`
- Validation: Swift typechecks for the DIT Printer app, print bridge, and ParaShoot erase bridge; `bash -n scripts/build_dit_printer.sh`; `bash scripts/build_dit_printer.sh`; DIT Printer TSPL renderer smoke test for 72 x 51 and custom 60 x 40 mm stock; print bridge idempotency test; erase bridge negative test rejecting equal card/destination before any ParaShoot CLI operation; `codesign --verify --deep --strict 'build_printer/DIT Printer.app'`; `git diff --check` all passed.
- Follow-up/risk: The combined Copy Job template intentionally invokes ParaShoot with one explicitly verified destination and does not wait. It still changes card filesystem state. Validate Silverstack resource ordering, ParaShoot card detection, physical-card restore, and real destination behavior with a disposable card before enabling the Copy Job Post Step in production.

### 2026-08-09 — [codex] Add XML-first Sony model identification
- Commit: `uncommitted`
- Branch: `codex/swift-1.1-hardening`
- Changed: `src_swift/MediaScanner.swift`, `src_swift/Models.swift`, `src_swift/Views/MainDetailView.swift`, `src_swift/Views/SettingsView.swift`
- Validation: `swiftc -typecheck -target arm64-apple-macosx14.0 $(find src_swift -name '*.swift' -print)`; `bash -n scripts/build_swift_app.sh`; `git diff --check`; `./scripts/build_swift_app.sh`; a standalone `/tmp` Sony-card fixture verified XML results `ILME-FX30 -> Sony FX30`, `ILCE-7M4 -> Sony A7M4`, and direct `CameraModelName ZV-E1 -> Sony ZV-E1`.
- Follow-up/risk: XML/XMP is read first from at most 20 Sony-card sidecars of at most 1 MiB each. Only if it has no Sony model, the setting is enabled, and a representative video exists does one 2-second `exiftool -fast2` fallback run. A real card is still required to validate vendor-specific XML placement and exiftool field availability for every camera generation; no filename is used to infer a model.

### 2026-08-09 — [codex] Complete 1.1 remount flow and Printer audit interface
- Commit: `2c9f72d`
- Branch: `codex/swift-1.1-hardening`
- Changed: `src_swift/RenamerEngine.swift`, `src_swift/App.swift`, `src_swift/Views/MainDetailView.swift`, `src_swift/Models/PrinterAuditExport.swift`, `src_swift/Models/RenameHistoryStore.swift`, `src_printer/`, `docs/renamer_printer_audit_interface.md`, `README.md`
- Validation: Swift typecheck; both build-script syntax checks; Renamer audit Reader fixture; TSPL label smoke test; standalone Printer build and codesign verification; 1.1 app/zip/DMG build and codesign verification; `git diff --check`.
- Follow-up/risk: Renamer executes `diskutil unmount force` and `diskutil mount` only after same-node/UUID preflight and then verifies the remounted node/UUID/name/mount point. No real card was unmounted during development. A disposable-card test must verify the actual Silverstack state transition. Printer remains separately built and can only read the versioned local audit JSON; its match is display context, never copy verification or erase authority.

### 2026-08-09 — [codex] Require universal Developer ID notarized releases
- Commit: `f13014a`
- Branch: `codex/swift-1.1-hardening`
- Changed: `scripts/build_swift_app.sh`, `README.md`
- Validation: `/bin/bash -n scripts/build_swift_app.sh`; `swiftc -typecheck` for `arm64-apple-macosx14.0` and `x86_64-apple-macosx14.0`; native optimized compilation of both slices; `lipo -create`, `lipo -verify_arch`, and `file` confirmed an `arm64` + `x86_64` universal binary; missing-credential execution failed before changing `Release/`; local `spctl --assess --type open --context context:primary-signature` accepted the command syntax and rejected the old ad-hoc DMG as expected; `git diff --check` passed.
- Follow-up/risk: No valid Developer ID identity or notarytool profile is installed on this Mac, so Developer ID signing, notarization, stapling, and successful Gatekeeper acceptance could not be executed. The existing `Release/` remains the previous arm64-only ad-hoc package and must not be distributed as the new release. The strict pipeline validates credentials first and publishes staged artifacts only after all required checks pass.

### 2026-08-09 — [codex] Correct About copy and document ARRI Reference Tool CMD
- Commit: `2270cf4`
- Branch: `codex/swift-1.1-hardening`
- Changed: `src_swift/Views/AboutView.swift`, `docs/research_codex_device_manager_cli.md`
- Validation: ARRI Reference Tool official product page, 1.0.0 manual, macOS universal package, `art-cmd --help`, HDE Transcoder page, and ARRI supporting-tools document checked; Swift typecheck and optimized executable compilation passed for `arm64-apple-macosx14.0` and `x86_64-apple-macosx14.0`; `/bin/bash -n scripts/build_swift_app.sh`; `git diff --check`.
- Follow-up/risk: Public ARRI materials do not confirm a CODEX Device Manager CLI or `codex-hde` command. Existing `MediaScanner.swift` and `MainDetailView.swift` still probe/display `codex-hde` and call the fixed 60% estimate an official model; changing that behavior requires user approval. ART CMD 1.0.0 reads/processes/verifies HDE input but does not document HDE output or a size-only estimate command.

### 2026-08-09 — [codex] Add explicit ad-hoc GitHub prerelease flow
- Commit: `eca1ba1`
- Branch: `codex/swift-1.1-hardening`
- Changed: `scripts/build_swift_app.sh`, `scripts/publish_github_release.sh`, `docs/github_release_1.1.md`, `docs/github_release_notes_1.1.md`, `README.md`
- Validation: Swift typecheck passed for `arm64-apple-macosx14.0` and `x86_64-apple-macosx14.0`; both scripts passed macOS Bash syntax checks; invalid release modes fail before build; ad-hoc build produced universal App/ZIP/DMG; App, ZIP-extracted App, DMG-contained App, and DMG passed `codesign --verify`; `lipo -verify_arch arm64 x86_64` passed for every App copy; SHA-256 verification passed; mounted DMG contents and warning text were inspected; `spctl` rejected the unnotarized App as expected; publish script failed before mutation when GitHub authentication was absent.
- Follow-up/risk: Public repository `iNGlY/DIT_Renamer` was created, the branch and annotated `v1.1.0` tag were pushed, and the DMG, ZIP, and checksum file were published as a GitHub Pre-release from commit `11227ce`. GitHub-reported asset digests match the local SHA-256 values. Developer ID signing and notarization remain required for a normal stable distribution.

### 2026-08-09 — [codex] License DIT Renamer under Apache-2.0
- Commit: `a89e5a6`
- Branch: `codex/swift-1.1-hardening`
- Changed: `LICENSE`, `NOTICE`, `README.md`, Swift entry/About attribution, release documentation, and release packaging scripts
- Validation: `LICENSE` matched the official Apache License 2.0 text byte-for-byte after substituting the appendix copyright placeholder with `Copyright 2026 DIT247`; Swift typecheck passed for arm64 and x86_64; both release scripts passed macOS Bash syntax checks; `git diff --check` passed; GitHub default branch was pushed; `v1.1.0` notes were updated and `LICENSE`/`NOTICE` assets uploaded.
- Follow-up/risk: The immutable `v1.1.0` tag still resolves to pre-license commit `11227ce`, so GitHub's automatic tag source archives do not contain the new legal files. The attached LICENSE/NOTICE and updated release notes state the license for the distributed assets; the next version tag must point to a commit containing `a89e5a6` or later.
