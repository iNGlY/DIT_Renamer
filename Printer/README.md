# DIT Printer

Standalone macOS SwiftUI utility for turning a successful Silverstack Copy Job
into an operator-reviewed camera-card label. It is intentionally isolated from
DIT Renamer: the only Renamer interaction is an optional read-only audit JSON
lookup.

## Build

```bash
cd Printer
./scripts/build_printer.sh
open "build/DIT Printer.app"
```

The built app contains `DITPrinterBridge` and `ParaShootEraseBridge` helpers.
Install the bundle in `/Applications` before enabling a Silverstack post-step.
Always use `Printer/build/`; any root-level `build_printer/` directory is a legacy
ignored artifact from before this project was isolated.

## Layout

| Path | Purpose |
| --- | --- |
| `src/DITPrinterApp.swift` | SwiftUI application and operator workflow |
| `src/CUPSPrinter.swift` | PDF/TSPL/ZPL/EPL/CPCL rendering and print submission |
| `src/PrintProfileStore.swift` | Persistent CUPS/CLI output profiles and command language |
| `src/LabelTemplateStore.swift` | Persistent stock/template configuration |
| `src/Shared/PrinterJob.swift` | Persisted job, template, signal, and history model |
| `src/DITPrinterBridge.swift` | Silverstack manifest receiver and local job queue writer |
| `src/Silverstack/` | Silverstack Lua post-step scripts |
| `docs/` | Deployment material |

Read [AGENTS.md](AGENTS.md), [CONVERSATION_EXPORT.md](CONVERSATION_EXPORT.md),
and [ANTIGRAVITY_PROMPT.md](ANTIGRAVITY_PROMPT.md) before making changes.
