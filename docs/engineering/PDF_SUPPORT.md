# PDF Studio: engine and support boundaries

Recorded 2026-10-28 for the selective consolidation. `dart_pdf_editor` 10.0.0 supplies the offline editor and `pdf_document` 10.0.0 supplies bounded inspection and ordered merging. Both are pinned; their real integration still needs full Flutter and device testing.

## Implemented source

- Open through the shared document picker. Reject over-48-MiB input, invalid headers, encrypted files, zero-page documents and certain damaged page trees/first pages before loading the editor. Inspection runs off the native UI isolate.
- A new editor identity is created for every successful open, including files with the same name. Replacing or closing an open PDF asks the user to confirm loss of unsaved edits.
- The editor can return edited bytes, page exports or split outputs. Each is inspected before a save dialog. Split preflights every part before writing any, accepts at most 100 parts and 48 MiB aggregate output, stops on cancellation/error and reports confirmed partial writes.
- Combine up to 10 PDFs within 48 MiB aggregate input in the selected order. Each input and the result are inspected and the resulting page count is checked.
- The save picker proposes new names but **can overwrite an existing file** if that is the selected destination. Choose a different location/name, retain an independent original and verify each saved file.

Inspection is a limited structural check, not a complete validator: successfully opening the first page and page tree does not guarantee every page, digital signature, form, object or feature is intact. Byte caps are not peak-memory caps. Password unlocking, encrypted output and guaranteed structural compression are unavailable. Complex, malformed or unusually large PDFs may fail.

Scan & assemble produces image-only PDFs; its selected-page OCR handoff opens Text extraction separately. OCR searchable PDF has an image and original recognized-word layer, not editable text. New-design and Office content PDFs use the existing PDF writer; these are distinct from editing an imported PDF.

## Release checks

Run the full Flutter test suite and analyzer on the exact source, then exercise real picker/editor/page-export/split/combine flows, cancellation and low-memory devices. Verify output and page order in an independent PDF reader and test a representative corpus including rotations, forms, fonts, annotations, damaged/encrypted files and digital signatures. No current signed installation or Android-device result is claimed.
