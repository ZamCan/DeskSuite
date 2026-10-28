# PDF support: what is real, what is not

Last verified 2026-10-28 against `main`. Nothing in this file is inferred from a
button existing; each claim names the code and the test behind it.

## Engine

| Layer | Package | Licence | Native code |
| --- | --- | --- | --- |
| Viewer and editor widgets | `dart_pdf_editor` 10.0.0 | Apache-2.0 | None — pure Dart, renders to the Flutter canvas |
| Document model (page tree, boxes, save) | `pdf_document` 10.0.0 | Apache-2.0 | None |
| Object layer | `pdf_cos` 10.0.0 | Apache-2.0 | None |
| Raster/vector pipeline | `pdf_graphics` 10.0.0 | Apache-2.0 | None |

Because the engine is Dart, it builds in the same CI job as the rest of the app
and needs no NDK, no native packaging and no server. That is why it was chosen
over PDFium bindings: the build constraint in this repository is "compiles and
tests in GitHub Actions or Termux", and a Dart engine satisfies it while a
native one would need a separate ABI matrix.

## Implemented

`lib/pdf/pdf_inspection.dart`

- `looksLikePdf` — accepts the header anywhere in the first 1024 bytes, as the
  format allows a preamble, and nothing at all after that.
- `inspectPdf` — page count, byte length, encryption state, first page box in
  points and millimetres, formatted size. Refuses empty files, files over 96 MB,
  non-PDF files, files with no pages, and encrypted files, each with a specific
  message. A damaged file that still carries pages opens with the real count.
- The original bytes are never modified: a test reads them before and after.

`lib/pdf/pdf_studio_page.dart`

- Open a PDF through the existing `DocumentPicker` seam, showing page count,
  size and page box in the header.
- The editor surface is injected (`PdfEditorBuilder`), so the screen's open,
  validate, save and error paths are tested without rendering a PDF.
- Exports go through `FileGateway.save` as new files: `name-edited.pdf`,
  `name-pages.pdf` and `name-part-N.pdf` for a split. A cancelled save is
  reported as cancelled, never as success.
- Bytes returned by the editor are re-validated as a PDF before they are written;
  an editor that returns something else produces an error and writes nothing.

## Before this change

The conversion catalogue declared "Existing PDF → images, edited pages or
compressed PDF" **unavailable** and the navigation showed a `PLANNED` PDF entry.
Both are gone. The catalogue now carries a real PDF route, and the single
remaining unavailable route is password-protected PDFs, which is still true.

## Not implemented, and not claimed

- **Merging two existing PDFs** into one file from the app's own UI. The engine
  can insert pages from another document, but DeskSuite does not expose a merge
  workflow yet, so the catalogue lists it as unavailable.
- **Compression to a target size.** The engine has a compressor; DeskSuite does
  not expose it yet.
- **PDF → Office / PDF → images as a batch conversion** outside the viewer.
- **Reflowing or editing the existing text inside a page.** Annotations and form
  fields are edits *over* the page; they do not re-typeset it. DeskSuite never
  calls such a PDF "fully editable".
- **Cryptographic signing.** No PAdES workflow is exposed.
- **Password-protected PDFs.** Refused with an explicit message.
- **On-device rendering verification.** The widget tests drive the screen with a
  stub editor; no test in this repository has rendered a PDF page on a phone.
  The engine's own test suite is not run here.

## Limits

- 96 MB maximum file size (`maxPdfBytes`).
- Very large or damaged documents may open with fewer pages than a desktop reader.
- The editor keeps the whole document in memory; a phone with little free RAM can
  still fail on a large file, and the failure is reported rather than hidden.
