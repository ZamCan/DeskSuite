# Changelog

## Unreleased — document workflows (not a release)

- Added manual four-corner projective correction with optional A4/Letter proportions, rotate and grayscale/fixed-threshold enhancement; ordered A4/Letter image-only PDFs and bounded local draft recovery. Android camera uses `image_picker` and an injectable lost-capture boundary; native execution remains unverified.
- Added exact-pixel Photo resizing, compare/undo/reset and review of actual encoded dimensions/bytes; added an explicit supported/unavailable conversion catalogue.
- Added skippable welcome, revisitable tutorials, fictional page/design samples and a synthetic practice photo; tutorials call the real processors. Added D+S master logo, Android adaptive/legacy/monochrome resources and splash; Android resource build/rendering remains unverified.
- Added scan, draft failure/reopen, camera-fake, sample, responsive layout and navigation tests; user guide, conversion registry, engine evaluation and Pub dependency notice inventory.

Host baseline (before these changes): 44 tests passed. Later targeted scan (7), Photo widgets (4), sample assets (2), scan processor (5), and conversion/navigation (3) passed; analyzer passed before a later test-assertion edit. A two-page image PDF was independently parsed and pixel/order checked. **The complete final suite has not been run**, and no current APK/AAB or device test was performed. See [validation](docs/engineering/VALIDATION.md).

Still unavailable: OCR and searchable PDFs, existing-PDF reader/editing, office conversions, automatic page detection and cloud sync. This work is not release-ready.

## Earlier unreleased integrated foundation

- Restored the earlier Photo, Notes, Print, Business and editor modules within current main's physically dimensioned Creative Studio workspace, without deleting earlier project files or replacing main's workflow.
- Added editable text/shapes/images, manipulation, history, local save/reopen and safe copy import/export; added bounded one-way `.dsproject` conversion and same-installation discovery.
- Added bounded local photo operations, repeated-photo sheet preview/PDF/print handoff, accurate PDF page geometry and injectable print adapter.
- Hardened local writes, failure/retry/unsaved-exit behavior, catalogue stock counting and exact minor-unit calculations; added catalogue and notes exports.
- Preserved current main's checked-in Android scaffold and package ID; debug builds are explicitly for testing and release signing requires a local private configuration. Corrected the build script's repository-root detection.
- Added host tests, offline/privacy/format/printing documentation, attribution and an inactive CI proposal.

Validation in this execution: Flutter 3.47.8 / Dart 3.13.7; formatter and analyzer passed and 44 integrated host tests passed sequentially. System-print tests use fakes. No integrated Android/desktop packaging, actual printer or device testing was performed. The earlier creative-branch debug APK is not this integration.
