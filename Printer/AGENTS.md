# DIT Printer Scope

This directory is a self-contained macOS DIT Printer project. Work only inside
`Printer/` unless the user explicitly authorizes a change outside it.

## Hard boundaries

- Do not edit `../src/`, `../src_swift/`, `../src/web/`, or any DIT Renamer
  build, release, or settings files.
- DIT Renamer is an external, read-only audit provider. Its JSON snapshot can
  add label context but can never be used as a control channel.
- Do not send a real print job, invoke a custom printer CLI, run ParaShoot
  erase, mount/eject media, or run destructive disk commands during development
  or visual work.
- The ParaShoot bridge is safety-critical. Do not change it unless the user
  explicitly requests that integration work and provides approval for the
  intended behavior.

## Structure

- `src/`: SwiftUI app, bridges, renderer, templates, profiles, and tests.
- `src/Silverstack/`: Lua post-step scripts.
- `scripts/build_printer.sh`: standalone arm64 macOS build.
- `docs/`: deployment and integration guides.
- `build/`: generated, ignored output.

## Frontend handoff

Antigravity may modify the SwiftUI experience in `src/DITPrinterApp.swift` and
supporting Printer-only stores. Preserve the persisted `DITPrinterJob`,
`LabelTemplate`, and `PrintProfile` fields unless a migration is added. The app
must keep signal source/received time visible, require card reuse count before
submission, and retain template/profile/history persistence.

## Validation

From `Printer/`:

```bash
bash -n scripts/build_printer.sh
./scripts/build_printer.sh
codesign --verify --deep --strict "build/DIT Printer.app"
```

Run focused renderer tests with the source list from `src/Tests/`. Never use a
real printer or removable camera media as a test fixture.
