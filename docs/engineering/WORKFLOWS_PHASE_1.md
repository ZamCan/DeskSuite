# Document workflow phase 1

## Implemented scope

Phase 1 adds reusable date-aware visual stamps and a finger/stylus signature drawing tool to the existing design canvas. The stamp becomes an editable text layer; the signature is rasterized to a transparent PNG and inserted as an image layer. Existing save, layer manipulation, undo/redo and PNG/raster-PDF export pipelines are reused.

## Stamp presets

DRAFT, APPROVED, PAID, RECEIVED, CONFIDENTIAL, COPY and VOID are available, with an optional custom label and optional date. The date is captured when the user places the stamp. The stamp remains editable artwork.

## Signature behavior and limits

The user draws on a signature surface. The drawing is exported to a transparent PNG and inserted into the design. The user can move, resize, duplicate or delete it like other image layers. This is a **visual signature image**, not a cryptographic digital signature, identity verification or tamper-evident PDF signature.

## External file handoff

The workspace includes an **Open with an app** action for PDF, Word, Excel, PowerPoint, OpenDocument, RTF, text, HTML and common image files up to 50 MB. Android receives the selected bytes in a bounded flow, writes them only to an app cache directory, and opens a chooser using a scoped FileProvider URI. The source file is not overwritten. A compatible installed application is required. This is an external handoff, not in-app Office/PDF editing.

## Current limits

- Stamps and drawn signatures are added to DeskSuite design projects, not directly to imported PDF, DOCX, XLSX or PPTX files.
- PDF export remains a single-page raster export from the design canvas.
- Office-file parsing, general PDF editing, camera scanning, OCR, and dedicated image resizing/compression remain future implementation phases.
- The application still needs a Flutter CI run and device validation for this branch before this feature can be considered release-ready.

## Verification

Run:

```bash
flutter pub get
dart format lib test
flutter analyze
flutter test
```

Review the stamp date test and existing editor/export regression tests. Confirm actual Android behavior in the build artifact before distribution.
