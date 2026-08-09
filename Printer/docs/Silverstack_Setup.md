# DIT Printer and Silverstack Setup

DIT Printer is a separate macOS application for printing camera-card labels after a Silverstack Copy Job, including Verify, finishes successfully. It is not part of DIT Renamer 1.1.1.

DIT Printer does not mount, rename, eject, verify, or delete camera media. The optional ParaShoot bridge is a separate integration. It can request ParaShoot's reversible erase workflow only from the documented Silverstack post step.

## Workflow

Use `src/Silverstack/DITPrinterAndParaShootAfterCopyVerify.lua` as the final post step of a Copy Job with Verify set to **Included**. Configure its input files in this order:

1. Source camera card
2. Destination 1, verified by the same Copy Job

Silverstack calls the post step after the Copy Job and Verify finish successfully. The script then queues a label and, when configured, sends a separate request to ParaShoot. Silverstack does not wait for printing or erasure to finish. A later bridge error does not change the Copy Job's successful Verify result.

## Build and install

```bash
bash -n scripts/build_printer.sh
./scripts/build_printer.sh
open "build/DIT Printer.app"
```

Install `DIT Printer.app` in `/Applications` before enabling the Silverstack script. The script expects this helper path:

```text
/Applications/DIT Printer.app/Contents/Helpers/DITPrinterBridge
```

Print jobs are stored as JSON files in:

```text
~/Library/Application Support/DIT Printer/Jobs
```

A repeated `job_id` updates the existing job instead of creating another pending label. For isolated development tests, `DIT_PRINTER_DATA_DIRECTORY` can point to an empty test directory. Do not use that override on a live workstation.

## GP-M325F setup

1. Set the printer to the command language used by the selected profile. TSPL is used by GP-M325F; ZPL, EPL/EPL2, and CPCL are also available for compatible printers.
2. Add a macOS CUPS queue that passes raw data to the printer. Use a stable name such as `GP-M325F`.
3. Select that queue in DIT Printer and refresh the queue list.
4. Choose a stock preset or save a template with the correct width, height, and gap.
5. Calibrate and print at least 20 labels on each stock before field use.

DIT Printer renders variable text into a monochrome bitmap and writes it to the selected printer language, so Chinese Bin names and filenames do not depend on fonts installed in the printer. Built-in stock sizes are 72 x 51, 60 x 40, 50 x 30, and 80 x 50 mm. Custom templates are saved for the current macOS user. Physical calibration is still required for each printer and stock combination.

The profile editor also supports a generic CUPS PDF queue and a custom CLI. The CLI receives the generated PDF through a `{file}` argument. Templates can control the title, footer, note, and printed fields. Print history can be exported as CSV or JSON; these exports record the Printer workflow and do not replace Silverstack reports.

## Label data

Each label contains:

- Silverstack Bin name
- final asset filename supplied by the post step
- Copy Job completion time supplied by Silverstack
- card reuse count entered by the operator

The bridge rejects an empty Bin name or final-asset field. Both fields remain editable because Silverstack metadata APIs can differ between versions. Before deployment, run a test Copy Job and inspect the post-step manifest. The Lua script tries `getBinName` and `getFileName` first; update the getter lists only when the installed Silverstack version uses different API names.

The script uses the final item in Silverstack's `assets` array. Confirm that ordering on the installed version. It does not infer order from filesystem timestamps.

## Acceptance test

Before connecting a production printer, confirm that a successful Copy Job with Verify creates one pending print job and that a failed Copy or Verify creates neither a print job nor an erase request. Test Chinese names, long filenames, the highest expected reuse count, printer-offline recovery, CUPS retry, and a repeated post step.

Keep the job JSON files and printed labels as an operational record. They do not replace Silverstack's copy and verification reports.

## ParaShoot after Verify

The bridge calls ParaShoot with one source card and the one destination verified by the same Copy Job:

```text
parashoot erase --card <source-card> --destinations <verified-destination> \
  --min-destinations 1 --no-auto-add-shuttle-drives --machine-readable
```

Before making the request, it checks that the source is an existing `/Volumes` root, confirms removable/external status with `diskutil`, runs `parashoot is-card`, and confirms that the destination is a different existing directory. It does not use `--wait`, `--erase-empty`, or automatic shuttle-drive discovery.

Bridge results are written to:

```text
~/Library/Application Support/DIT Printer/ParaShootEraseJobs
```

Test this workflow with a disposable card and a known destination. ParaShoot erasure is reversible, but it still changes the card's filesystem state.
