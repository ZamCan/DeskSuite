# File formats and compatibility

| Format | Implemented support | Important limitations |
| --- | --- | --- |
| `.dsdesign` | Create, autosave, reopen, export/import an editable copy | Version 1 UTF-8 JSON (`format: desksuite.design`), physical page/object geometry in mm, ordered objects and base64-embedded images. Import gets a fresh ID. Maximum file 32 MiB, 100 objects, 4,000 characters per text object. |
| `.dsproject` | Earlier manual-save editor; import a copy into the new editor | Earlier schema 1 is converted using 25.4/96 mm per logical unit. The source stays untouched. Unknown layers/unsupported or oversized data are rejected; font and circle rendering can differ. Same-installation private files are listed; different Android IDs are isolated. |
| PNG/JPEG/WebP | Import into new canvas, Photo and scan draft | Picker/camera input limit 8 MiB per file. Design image decode limit 20 MP each / 24 MP total unique decoded images. Photo/scan limit 12 MP and 8192 px per side, 16 MiB processed encoded working data. First frame only; native picker/camera behavior is unverified. |
| PNG | Photo export and new canvas export | New canvas export at 150 or 300 dpi; PNG physical-DPI metadata is not guaranteed. |
| JPEG | Photo export | User-selectable quality; transparency flattened on white. Original file is never overwritten automatically. |
| PDF | Scan & assemble, OCR searchable-PDF export, Office conversion, new canvas, photo-sheet export and system printing | Scan PDFs contain up to 8 ordered images on A4/Letter with 10 mm margins and no searchable text. OCR can produce a searchable PDF from recognized image text. New canvas PDF is one physical-size flattened raster page. Photo sheet is one page with repeated contain-fitted images. No existing-PDF reader/import, page editing, merge or PDF compression. |
| TXT | Notes export | Plain UTF-8 text, not a rich document. |
| JSON | Business catalogue export | A copy of product records; importing/restoring it in the UI is not implemented. Money is stored in integer hundredths; the UI currently labels amounts TZS and has no currency selector. |
| DOCX, XLSX, PPTX, ODT, ODS, ODP, RTF | Readable content; content editor can edit paragraphs/table cells and export a new ODT/ODS/PDF/TXT/CSV copy where available | Not a layout-faithful Office editor. Images, exact formatting, formulas, charts, macros and complex objects may be lost. Original file is not overwritten. Legacy DOC/XLS/PPT need an external office engine. |

Canvas export is capped at 16 million pixels and 8192 pixels per side; A4 at 300 dpi fits but A3 at 300 dpi does not. Limits reduce, but cannot eliminate, memory failures on every device. Malformed/over-limit inputs are rejected; OS pickers may cache before Dart validates a stream. See [conversion registry](CONVERSIONS.md), [printing](PRINTING.md) and [privacy/security](PRIVACY_AND_SECURITY.md).

Export individual project/notes/catalogue copies to a user-controlled location and verify them. There is no complete suite backup/restore yet. Especially before uninstalling, changing app IDs or switching signing keys, keep the old installation and its data until the exported copies are verified.
