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
- Commit: `pending`
- Branch: `codex/swift-1.1-hardening`
- Changed: `src_swift/RenamerEngine.swift`, `src_swift/App.swift`, `src_swift/Views/MainDetailView.swift`, `src_swift/Models/PrinterAuditExport.swift`, `src_swift/Models/RenameHistoryStore.swift`, `src_printer/`, `docs/renamer_printer_audit_interface.md`, `README.md`
- Validation: Swift typecheck; both build-script syntax checks; Renamer audit Reader fixture; TSPL label smoke test; standalone Printer build and codesign verification; 1.1 app/zip/DMG build and codesign verification; `git diff --check`.
- Follow-up/risk: Renamer executes `diskutil unmount force` and `diskutil mount` only after same-node/UUID preflight and then verifies the remounted node/UUID/name/mount point. No real card was unmounted during development. A disposable-card test must verify the actual Silverstack state transition. Printer remains separately built and can only read the versioned local audit JSON; its match is display context, never copy verification or erase authority.
