# PDF Studio engine and support boundaries

Recorded 2026-10-27 for the initial PDF Studio integration.

## Engine choice

DeskSuite pins `dart_pdf_editor: 10.0.0` and uses its `PdfEditorView` inside `lib/pdf/pdf_studio_page.dart`. The package documents a pure-Dart renderer/editor with no platform views or native PDF libraries, and support for Android, iOS, Linux, macOS, Windows and web. It is Apache-2.0 licensed. Upstream documentation: https://pub.dev/packages/dart_pdf_editor.

The version is pinned because this is a new dependency with a fast release cadence. Re-evaluate version compatibility and security before upgrading. The package adds a substantial editing engine and dependencies; installed APK size, cold-start cost, peak memory and rendering performance have not yet been measured on target phones.

## Current integration

- Opens an existing PDF selected through DeskSuite's document picker.
- Validates the PDF signature before passing the bytes to the editor.
- Enforces a 64 MiB input and edited-output limit to reduce avoidable memory pressure on phones.
- Embeds the editor's supported viewing, search, annotation, page, stamp and form tools.
- Exports through DeskSuite's file gateway as `edited-<source-name>.pdf`.
- Never writes directly over the selected source bytes.
- Does not require a cloud service or API at runtime.

## Not a blanket compatibility guarantee

A signature check only confirms that the bytes begin with a PDF header; it does not prove the whole document is valid. Password-protected, malformed, encrypted or complex real-world documents may fail or use significant memory. Files over the 64 MiB app limit are rejected before editor initialization. Users should keep an independently verified original. Native save-provider behavior and accessibility still need device tests.

The engine is not yet validated against a broad production PDF corpus. CI must pass on the repository's supported targets before merging. Follow-up validation should include scanned PDFs, large mixed image/vector documents, forms, links, embedded fonts, rotations, annotations, page reordering/deletion, save/reopen comparisons, and memory pressure on low-RAM Android devices.

## Scope boundaries

PDF Studio is the existing-PDF reader/editor. Scan & assemble remains a separate workflow that accepts images and exports image-only PDFs. OCR remains available through Text extraction and is not automatically applied to every PDF. DeskSuite's generated design PDFs and Office content PDFs continue to use the existing `pdf` writer; they are separate from editing an imported PDF.
