# Architecture

## Choice and boundaries

Flutter/Dart is the single UI stack: native Android packaging and plugins first, with shared logic reusable on Windows/Linux. Desktop shells and plugin behavior still require host builds and testing. We did not substitute a web application or add a second UI framework. `file_picker` handles user-directed file selection/export, `image_picker` delegates Android camera capture to an installed camera app, `path_provider` finds app support storage, `image` performs local photo transformations, and `pdf`/`printing` generate and hand PDFs to OS services. All core workflows are local; OS print services may themselves use the network if the user selects a network printer.

## Modules

- `lib/main.dart` and `lib/workspace/workspace_screen.dart`: current main's responsive workspace, files and settings shell. `lib/legacy_studios.dart` restores the earlier editor, Notes, Photo, Print and Business screens as live studios; this still-large integration file should be split further.
- `lib/design/`: validated versioned document, immutable-style snapshots, geometry/hit testing, editing/history, canvas renderer and editor UI. Screen and PNG/PDF rendering share the painter.
- `lib/workspace/`: project browser, new-design dialog, bounded file-picker boundary, `.dsdesign` repository and one-way earlier-project conversion.
- `lib/core/`: random IDs, shared app-support root, queued bounded local files and same-directory temporary-file replacement/recovery.
- `lib/images/`: validated first-frame photo decode and operations dispatched to a background isolate.
- `lib/document_scan/`: Android camera gateway, projective manual correction, tone operations, bounded ordered image-PDF generation, and manifest-last recoverable private draft. OCR and PDF reading are not provided.
- `lib/workspace/conversion_catalog.dart`: declared implemented and unavailable routes; its page links to actual tools instead of faking conversions. `getting_started_page.dart` links fictional examples to those tools.
- `lib/printing/`: physical unit conversion and flattened design PDF, bounded photo-sheet layout/PDF, and injectable system-print boundary.
- `lib/business/`: typed catalogue, integer minor-unit money, arbitrary-precision totals and per-repository serialized stock updates.
- `android/`: current main's checked-in Android scaffold and package identity, pinned Gradle distribution/checksum and no debug-key fallback for release signing.
- `test/`: models, persistence, conversion, rendering/PDF, photo, print-adapter and phone-size interaction tests.

## Storage and reliability

Current modular `.dsdesign` files and settings remain under `getApplicationDocumentsDirectory()/DeskSuite`; the earlier prototype's `.dsproject` files, `notes.txt` and `products.json` remain under `getApplicationSupportDirectory()/desksuite`. The browser searches the latter for earlier projects and copies conversions into the current root. Both roots belong to the **same** installed application ID; cross-ID access is not possible. The new editor autosaves debounced snapshots; save failures are visible and leaving is guarded. The earlier editor requires manual Save and warns on unsaved exit. Notes debounce and retry failed writes. A single scan draft lives under the existing support root's `scan_draft`; new page assets are committed before the manifest, with previous committed pages preserved on a failed replacement. The active unsaved scan state and a pending camera result are only in memory until successfully committed or exported. Same-directory temp files are flushed before replacement; on Windows a `.bak` is recovered if a replacement was interrupted. This improves safety but is not a full filesystem journal, backup, or guarantee against every power loss.

Queues serialize operations **within a repository/store instance**, not across multiple processes or independently created repository instances. The catalogue is not an ACID database or financial ledger. Migration preserves source `.dsproject` files and unknown product fields; invalid files are reported rather than silently rewritten. Two Android application IDs cannot read one another's private data. Settings retain main's dark workspace/design theme; restored prototype studios currently use light surfaces.

## Processing and platform boundaries

Photo processing and PDF assembly use background isolates; UI canvas rasterization still consumes memory and is subject to explicit dimensions/pixel limits. Imported files are bounded and validated, but native picker implementations may cache/copy before the Dart stream limit is enforced. Printing is a platform adapter; host fakes do not prove printer discovery, spooler correctness or physical dimensions on paper. Native picker, lifecycle, process-death and upgrades need device tests. See [printing](PRINTING.md), [formats](FILE_FORMATS.md), and [privacy](PRIVACY_AND_SECURITY.md).
