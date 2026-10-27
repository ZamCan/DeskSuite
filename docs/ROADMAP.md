# Capability status

Statuses refer to the current code. “Tested” means automated host Flutter tests unless a device is explicitly identified.

## Implemented and tested
- Local image resize/encode service: exact pixel sizing, aspect-ratio fit, PNG output, adjustable-quality JPEG output, 20 MP input and 16 MP output safety bounds, with unit tests.
- Android external-file handoff for supported PDF, Office, OpenDocument, text, HTML and image extensions; the original file is passed read-only to a compatible installed app.
- Editable visual stamp layers with optional placement date and custom labels; unit tests cover date formatting.
- Finger/stylus signature capture to transparent PNG, inserted as a normal image layer on the design canvas.

- Versioned structured design serialization and validation; unit and filesystem round trips.
- Layer geometry, rotated hit tests, drag history, rotated aspect-preserving image resize, undo/redo and physical unit conversions.
- Local atomic-save path, serialized writes, failed-write preservation, malformed-file reporting, import as a new project and recovery of a replacement backup (host filesystem tests).
- Shared renderer, actual PNG/PDF generation, page dimension calculation and low-resolution calculation (host tests).
- Phone-sized widget flow: create, edit text, add an image through a test picker, undo/redo, export through a test saver, close and reopen.
- An engine workflow with Dart HTTP requests blocked during the test. This does not prove Android airplane-mode behaviour.

## Implemented but not fully tested

- Android runner and a debug APK have built; native picker/export integration, light/dark settings, shape and layer controls, and accessibility labels have host coverage, but no Android device or emulator has been exercised.
- PDF is a single-page, full-bleed raster at the chosen physical page size. Actual physical printer output and printer margins are not tested.
- Project save/recovery has host filesystem coverage, not hardware power-loss testing. History is session-only.

## In progress

- Android installation verification, device offline testing, accessibility and performance profiling.
- Creative editor usability: additional direct manipulation, layout tools, image quality controls and broader format validation.

## Not implemented

- Dedicated Photo Studio, passport/ID sheets, cropping, adjustment filters or background removal.
- Office documents, notes, spreadsheets/formulas, PDF import/merge/split and OCR.
- Visual stamps/signatures inside imported documents and cryptographic digital signatures.
- Direct printer services, imposition, print queue, print presets or printer-specific calibration.
- Business/POS, local database, products, stock, expenses, payments, receipts, profit reporting and integrated orders.
- Bulk backup/restore, cloud sync, encryption, accounts, analytics, desktop runners and desktop releases.
- A production-signed or store-ready release.

## Concurrent prototype integration

The repository's `main` gained separate Photo, Notes, Print and Business prototypes while this branch was developed. Their source and workflow are preserved on `main`, not included or tested in this branch. Reconcile those capabilities, storage paths and Android app identities before merging; see [INTEGRATION.md](INTEGRATION.md).
