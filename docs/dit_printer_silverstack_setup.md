# DIT Printer (experimental)

`DIT Printer` is a standalone macOS application for an early, deliberately
separate label-printing workflow. A Silverstack Lab Copy Job with Verify
included sends a completion event to `DITPrinterBridge`; the bridge persists a
print job and opens the app. The operator enters the physical card reuse count,
verifies the label fields, then submits the job to a GP-M325F CUPS raw queue.

It does not alter, mount, rename, eject, verify, or delete camera media.
The optional `ParaShootEraseBridge` is a separate, explicit post-verification
integration. It invokes ParaShoot's reversible erase workflow only when the
documented Copy Job Post Step with Verify included is installed.

## Trigger timing: Copy Job with Verify included

When Verify is configured as **Included** in the Copy Job, install
`src_printer/Silverstack/DITPrinterAndParaShootAfterCopyVerify.lua` as the
Copy Job's Post Step. Its Input Files must be ordered as source card first,
then destination 1. The single `onFinish(..., success)` callback emits the
print and ParaShoot signals together only after that Copy Job, including its
Verify, finishes successfully.

Both bridges are launched in the background. Printing is queued for the DIT's
reuse-count entry while ParaShoot independently preflights and performs its
reversible erase workflow. The Silverstack job does not wait for the erase to
finish.

The label states `Silverstack Copy + Verify complete`. A later bridge failure
does not change the successful Copy Job/Verify result.

## Build and install

```bash
bash -n scripts/build_dit_printer.sh
./scripts/build_dit_printer.sh
open "build_printer/DIT Printer.app"
```

Install the generated `DIT Printer.app` in `/Applications` before enabling the
Silverstack script. The script invokes this fixed path:

```text
/Applications/DIT Printer.app/Contents/Helpers/DITPrinterBridge
```

The app ledger is stored at:

```text
~/Library/Application Support/DIT Printer/Jobs
```

Each job is a JSON file. A repeated `job_id` is treated as the same job, so a
Silverstack retry does not create another pending label.

For an isolated development test only, set `DIT_PRINTER_DATA_DIRECTORY` to an
empty test directory before launching the app or bridge. This overrides the
normal job ledger location and must not be used for a live station.

## GP-M325F setup

1. Pair/connect the printer and use its self-test/settings page to switch it
   to **TSPL label mode**.
2. In macOS add a queue that passes raw data through to the printer. Give it a
   stable name such as `GP-M325F`.
3. In DIT Printer, choose that queue and press **Refresh printer queues**.
4. Use the label-tag toolbar button to select a stock preset or save a custom
   width, height, and gap template. Print at least 20 labels using each actual
   stock before field use.

DIT Printer rasterizes all variable fields into a TSPL `BITMAP` command. This
allows Chinese Bin names and file names without relying on a printer-resident
Chinese font. Built-in stocks are 72 x 51, 60 x 40, 50 x 30, and 80 x 50 mm.
Saved custom templates persist for the current macOS user and can be selected
by every Silverstack project on that workstation. The printer and stock still
require physical calibration.

## Required label fields

The job editor shows and prints:

- Silverstack Bin name
- final asset filename supplied by the Silverstack Post Step
- copy-completion timestamp (UTC from Silverstack)
- manually entered physical card reuse count

The bridge rejects an empty Bin name or final-asset field. The app keeps both
fields editable because Silverstack metadata getter names may differ between
versions and workflows. Before field deployment, run a test card and inspect
the manifest in the Silverstack working directory. `getBinName` and
`getFileName` are attempted first in the Lua template; update the small getter
lists in `binNameFor` and `lastAssetNameFor` if that installation uses other
API names.

The post-step asset order must be tested on the installed Silverstack version.
The template uses the final element returned in `assets`; it does not infer
copy order from filesystem modification times, because that would make the
label less trustworthy.

## Dry run and acceptance

Before connecting the printer, use a temporary CUPS queue or keep the app open
and confirm that a Copy Job with Verify included creates one pending job.
Confirm the timestamp is the completed Copy Job time and that a deliberately
failed Verify creates neither a label task nor an erase request.

Finally test: Chinese names, long filenames, the highest expected reuse count,
printer offline behavior, CUPS retry, and re-running the same Post Step. Keep
the printed labels and job files as an operational audit trail.

## ParaShoot erase after Verify

ParaShoot 2.3.13 includes an official CLI whose `erase` command checks backup
availability before invoking ParaShoot's reversible erase operation. The
bundled bridge uses exactly one explicitly supplied, Silverstack-verified
destination as requested:

```text
parashoot erase --card <source-card> --destinations <verified-destination> \
  --min-destinations 1 --no-auto-add-shuttle-drives --machine-readable
```

For Copy Jobs with Verify included, use the combined
`DITPrinterAndParaShootAfterCopyVerify.lua` template above instead of this
separate template. `ParaShootEraseAfterVerification.lua` remains for workflows
where Verify is a distinct activity. In either case, Input Files must be
ordered as the source card first, then the destination that same Verify
activity checked.

Before calling ParaShoot, the bridge requires the card path to still be an
existing `/Volumes` root, confirms it is removable/external with `diskutil`,
checks it using `parashoot is-card`, and confirms that the destination is a
different existing directory. It never runs `--wait`, `--erase-empty`, or
auto-adds shuttle drives. Bridge output is written to:

```text
~/Library/Application Support/DIT Printer/ParaShootEraseJobs
```

An erase failure is recorded and returned to the Post Step, but the Lua script
does not throw an error, so a completed Silverstack Verify remains recorded as
successful. Test with a disposable card and a known destination before using a
production card. This workflow still changes the card's filesystem state even
though ParaShoot supports restoration.
