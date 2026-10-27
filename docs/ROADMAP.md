# Roadmap and release gates

## Implemented and host-tested

- [x] Integrated live studios into the current main workspace while preserving existing settings, project roots and earlier data paths.
- [x] Physically dimensioned editable design, text/shapes/images, arrangement, history, save/reopen, copy import/export, PNG and raster PDF.
- [x] Non-destructive earlier project conversion and interrupted-replacement recovery.
- [x] Local photo transformations and configurable one-page photo-sheet PDF.
- [x] Notes save/error/retry and TXT export; starter catalogue/stock counters, exact minor units and JSON export.
- [x] PDF physical-size and fake print-gateway behavior; sequential host suite, formatter and analyzer.

## Implemented, not fully validated

- [ ] Native Android file picking, saving, lifecycle/process death, actual printer discovery/output and accessibility on representative devices.
- [ ] Checked-in Android scaffold and external release-signing configuration: no integrated APK/AAB or device upgrade was built/tested in this execution.
- [ ] Windows/Linux/iOS plugins, generated desktop runners, packaging and OS-specific paths.
- [ ] System print scaling, colour, real margins and ID-photo requirements.

## Not implemented / next slices

- [ ] Full suite backup, restore, migrations and cross-ID import for notes/catalogue, with crash and storage-full tests.
- [ ] Transactional multi-instance database; complete POS, payment/refunds, sale lines, receipts, expense/profit reports and audit history.
- [ ] Rich document editor, spreadsheet/formulas, DOCX/XLSX interoperability and PDF page tools.
- [ ] Advanced image editing, arbitrary crop/adjustments and optional local segmentation; no model downloads without consent.
- [ ] Guides/snapping, professional vector/SVG tools, colour management, bleed/crop marks, imposition and printer calibration.
- [ ] Full accessibility, localization, dark theme across the restored studios, performance and low-memory profiling.

## Release gate: **not passed**

Require a signed, reproducible Android release with stable package ID and key custody; real-device cold/offline/upgrade/process-death/storage-full tests; native file-picker and printer checks; verified backup/restore; dependency/licence and permissions review; accessibility/performance testing; and a reviewed CI run/artifact. A host test pass or a debug APK is not equivalent to these gates.
