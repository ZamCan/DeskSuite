# PDF support: what is real, what is not

Updated 2026-10-28 for the isolated integration candidate. This is a source
inventory, not a claim that Flutter, third-party rendering, Android or device
checks passed for the integrated branch. Tests named below are written unless a
separate validation record says they were run.

## Engine

| Layer | Package | Licence | Native code |
| --- | --- | --- | --- |
| Viewer and editor widgets | `dart_pdf_editor` 10.0.0 | Apache-2.0 | None — pure Dart, renders to the Flutter canvas |
| Document model (page tree, boxes, save) | `pdf_document` 10.0.0 | Apache-2.0 | None |
| Object layer | `pdf_cos` 10.0.0 | Apache-2.0 | None |
| Raster/vector pipeline | `pdf_graphics` 10.0.0 | Apache-2.0 | None |

The selected engine is Dart rather than an NDK-based PDFium binding. That
avoids a separate native PDF-engine ABI matrix, but does not prove this merged
candidate builds or works offline on a device; both still require validation.

## Implemented

`lib/pdf/pdf_inspection.dart`

- `looksLikePdf` — accepts the header anywhere in the first 1024 bytes, as the
  format allows a preamble, and nothing at all after that.
- `inspectPdf` reports page count, byte length and first-page box. It rejects
  empty, non-PDF, zero-page and encrypted input, and input exceeding the 96 MiB
  in-memory inspection bound. The native picker has a smaller 48 MiB bound.
  Real malformed/encrypted fixtures and device performance remain to be checked.
- A written test checks that inspection does not mutate the input bytes; this
  does not prevent a user selecting the original as an export destination.

`lib/pdf/pdf_studio_page.dart`

- Open a PDF through the existing `DocumentPicker` seam, showing page count,
  size and page box in the header.
- The editor surface is injected (`PdfEditorBuilder`), so the screen's open,
  validate, save and error paths are tested without rendering a PDF.
- Exports through `FileGateway.save` suggest names such as `name-edited.pdf`,
  `name-pages.pdf` and `name-part-N.pdf`. The platform picker can allow an
  existing destination to be replaced; choose a different one to protect the source.
- Editor output is inspected before saving. All split parts are checked before
  the first save; cancellation stops the remaining prompts and reports confirmed
  writes. A stub-based control-flow smoke passes; the real PDF parser, platform
  picker and new widget tests remain unverified here.
- Closing or replacing an open editor asks about unsaved changes. This is a
  precaution, not change tracking or crash recovery.

## Before this change

The earlier conversion catalogue declared existing-PDF actions unavailable and
the navigation showed a `PLANNED` PDF entry. The candidate now links to the
PDF editor. Merge, target-size compression, password unlocking and batch image
conversion remain unavailable; the route is not evidence of device validation.

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

- The native picker accepts up to 48 MiB; in-memory inspection caps input and
  output at 96 MiB. Split output is limited to 100 files and 96 MiB combined
  before this screen writes anything. The external editor can allocate data
  before calling back, so these encoded-byte limits do not bound peak memory.
- Very large or damaged documents may open with fewer pages than a desktop reader.
- The editor keeps the whole document in memory; performance and low-memory
  behavior on a phone have not been verified.
