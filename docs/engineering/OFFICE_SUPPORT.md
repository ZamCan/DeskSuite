# Office documents: what DeskSuite really supports

Recorded 2026-10-27 against the code in `lib/office/`. Statuses describe
**implementation and host tests**, not device behaviour. No Android build was
produced or installed while this document was written; the Android build is left
to CI or an offline Termux build.

## Decision

LibreOffice **cannot** be embedded in an Android APK. It is a desktop-oriented
C++/Qt/GTK application; the Android ports that exist are large, dated and
unmaintained. Apache POI cannot be shipped inside the APK either: `poi-ooxml`
depends on StAX (`javax.xml.stream`), which Android does not provide, and the
historical workarounds fork the library in unsupported ways.

DeskSuite therefore reads and writes office packages **directly** in Dart over
the ZIP + XML containers, which is bounded, offline, testable and free of
copyleft or ATS issues. Anything beyond that (pixel-accurate rendering of
arbitrary documents) is delegated to an **optional external engine** that the
user installs:

| Path | Availability | Fidelity |
| --- | --- | --- |
| Built-in reader (`lib/office/office_reader.dart`) | Always, no network | Text, headings, emphasis, tables, sheet values. Layout is **not** reproduced. |
| Built-in writers (`lib/office/office_pdf.dart`, `office_writer.dart`) | Always | Real PDF with selectable text; real ODT/ODS packages; UTF-8 TXT; CSV. |
| Content editor (`lib/office/office_content_editor_page.dart`) | Always for readable formats | Edits readable paragraphs and table cells, then exports a new content-level ODT/ODS/PDF/TXT/CSV copy. Does not retain full layout or unsupported objects. |
| External engine (`ExternalOfficeEngine`) | Only when detected | Renders the original layout. |

LibreOffice **is** packaged for Termux (`pkg install libreoffice`, currently
26.8.2.2), so an Android user who wants high-fidelity conversion can install it
and point DeskSuite at `soffice`. DeskSuite does not bundle, download or
silently invoke it; when it is absent, those routes are not offered at all.

## Format matrix

| Input | Read | → PDF | → TXT | → CSV | → ODT | → ODS |
| --- | --- | --- | --- | --- | --- | --- |
| DOCX | Yes | Yes | Yes | — | Yes | — |
| XLSX | Yes | Yes | — | Yes | — | Yes |
| PPTX | Yes | Yes | Yes | — | Yes | — |
| ODT | Yes | Yes | Yes | — | Yes | — |
| ODS | Yes | Yes | — | Yes | — | Yes |
| ODP | Yes | Yes | Yes | — | Yes | — |
| RTF | Yes | Yes | Yes | — | Yes | — |
| TXT | Yes | Yes | — | — | — | — |
| HTML | Yes (text) | Yes | Yes | — | — | — |
| DOC / XLS / PPT | No (OLE2) | External engine only | — | — | — | — |
| PDF | No | — | — | — | — | — |

A dash means the route is not offered. It is never replaced by renaming a file.

## What is preserved and what is lost

Preserved: paragraph text and order, heading levels 1–6, bold/italic runs, table
rows and cell text, sheet names, cell values (including formula results and
booleans), slide text in slide order, ODF headings and paragraphs, explicit page
breaks.

Lost, and stated in the UI for every conversion:

- Exact fonts, sizes, colours, spacing and page layout of the original.
- Floating images, shapes, charts, embedded objects, macros, comments,
  tracked changes and footnotes.
- Text boxes and multi-column flow.
- Slide images, animations and speaker notes.
- Cell number formats, conditional formatting and pivot tables.
- Page size and margins of the original document (A4 is used).

## Resource bounds

`lib/office/office_package.dart` rejects a package before allocating unbounded
memory:

| Limit | Value |
| --- | --- |
| Compressed archive | 48 MB |
| Single part | 24 MB |
| Total uncompressed | 64 MB |
| Parts | 4000 |

These are covered by tests, including a 4100-part archive.

## Tests

`test/office_engine_test.dart` (29 tests) builds **genuine** DOCX, XLSX, PPTX,
ODT and ODS packages in memory, then asserts:

- container detection ignores misleading extensions;
- headings, emphasis, tables, page breaks, shared strings, formulas, booleans,
  inline strings, sheet order and slide order are read correctly;
- written ODT/ODS packages round-trip back through the reader;
- generated PDFs start with `%PDF-` and contain page objects;
- legacy OLE2 files are recognised and refused rather than mis-parsed;
- every route declares an engine, a fidelity and its limitations;
- an external engine that fails or returns a non-PDF is surfaced, never
  silently accepted;
- the source buffer is never mutated and output names are sanitised.

`test/office_convert_page_test.dart` covers detection, route filtering,
conversion, saving and unavailable routes. `test/office_content_editor_page_test.dart`
verifies that editing a genuine DOCX fixture and exporting ODT changes the
exported content while leaving the source bytes unchanged.

## Not verified

- Reading of large real-world documents produced by Microsoft Office or
  LibreOffice, including unusual namespaces and strict OOXML variants.
- Rendering fidelity, including right-to-left text and complex scripts.
- Behaviour of the external-engine seam against a real `soffice` binary.
- Any on-device measurement of memory or time.
