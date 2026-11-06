# Changelog

## Unreleased — Creative Studio vertical alignment (not a release)

- Added top/middle/bottom page alignment for the selected object in the Creative Studio inspector, next to the existing left/centre/right actions. It is undoable and saved with the project. Aligning an object that is already in place no longer creates an empty undo entry.
- Added controller and inspector widget tests. **Not run:** no Flutter/Dart toolchain was available when this was written; CI or a local `flutter analyze` and `flutter test` must confirm it. Nothing here claims a release.

## Unreleased — business baskets, receipts and backups (not a release)

- Added receipt currency and price-tier settings to the Business screen: the shop currency labels every money display and travels into recorded sales; it is a label only, with no exchange-rate behaviour implied.
- Added customer basket sales: several catalogue products with per-line quantities and retail/wholesale tiers complete into one itemised receipt (`recordCartSale`), reusing the serialized transaction, store bounds and sales-log rollback protection of single-product sales.
- Added automatic internal receipt storage: receipts are always kept (capped at 400), the newest 20 are listed, and reprinting an A5 PDF is optional and on demand.
- Added one-file business backups bundling the catalogue, stored receipts and shop settings, restored only after full validation. An interruption between restore writes can leave a partial state; in that case run the restore again.
- Prepared for a later cloud phase: the backup document is a complete bounded snapshot that a future Google Drive app-folder sync can upload unchanged. Sign-in/OAuth, consent-screen setup, a network permission change and device verification are still missing, and cloud sync is not integrated.
- Added cart-engine, backup round-trip/tamper and business widget-flow tests. Stabilized the hosted matrix suite with bounded scroll pumps, an explicit wait for the post-sale busy state to clear, and a currency assertion that waits for the saved setting to drive the summary. Nothing here claims a release.

## 0.2.1+4 — PDF merge and Office package safety integration

- Add ordered multi-PDF combination with source-count/byte limits, isolate-backed processing, output inspection and page-count verification; originals remain untouched.
- Preflight Office ZIP structure before decompression to reject oversized or ambiguous packages before the archive decoder runs.
- Polish PDF Studio busy/error states and remove the fixed “Offline” header claim; refresh current capability guidance.
- Increase the Android version code to 4 so the signed candidate can update an earlier build with the same private key.
- This remains an integration-validation build, not a production release. Full latest-head CI and physical-device checks are required.

## 0.2.0+2 — consolidated Android-first integration (validation build)

- Consolidated the scan, offline OCR/searchable-PDF, photo editing/optimization, Office content workflows, existing-PDF Studio, Creative Studio, print production, starter stationery inventory/POS, and shared brand assets into the main product.
- Added existing-PDF Studio navigation and save-as-copy workflow, scan recovery/widget regression coverage, editable design stamps/signatures, broader print media and photo-sheet templates, and canonical launcher/splash artwork validation.
- Preserved explicit capability limits: Office editing is content-level rather than full layout parity; automatic page detection/background removal, PDF encryption, full accounting/POS, SLM runtime and full backup/restore are not complete.
- This is an integration-validation version, not a production release. CI and physical Android camera, OCR, PDF, printing and update-install checks remain required.

## Unreleased — document and photo cleanup (not a release)

- Added local, adjustable uneven-lighting and adaptive black-and-white cleanup for document images, with temporary before/after previews, cancel/apply, existing draft undo/reset, and PNG or image-PDF export. Transparency is flattened to white; color, artwork or light text can be altered.
- Added a bounded 3 × 3 selective isolated-speck filter for photos up to 4 megapixels, zoom and original comparison. Borders and transparent neighborhoods are left alone; fine details may soften and this is not general restoration.
- Added a deliberately shadowed field-notes page and a noisy synthetic garden photo, in-app practice instructions, before/after evidence, and cleanup unit/widget tests. The actual Dart pixel cores passed DDC/Node smoke and sample checks; **the new Flutter tests, real codecs/UI, Android and full suite remain unverified**. See [validation](docs/engineering/VALIDATION.md).

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
