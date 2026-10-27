# File formats and compatibility

| Format | Implemented support | Important limitations |
| --- | --- | --- |
| `.dsdesign` | Create, autosave, reopen, export/import an editable copy | Version 1 UTF-8 JSON (`format: desksuite.design`), physical page/object geometry in mm, ordered objects and base64-embedded images. Import gets a fresh ID. Maximum file 32 MiB, 100 objects, 4,000 characters per text object. |
| `.dsproject` | Earlier manual-save editor; import a copy into the new editor | Earlier schema 1 is converted using 25.4/96 mm per logical unit. The source stays untouched. Unknown layers/unsupported or oversized data are rejected; font and circle rendering can differ. Same-installation private files are listed; different Android IDs are isolated. |
| PNG/JPEG/WebP | Import into new canvas and Photo | Picker limit 8 MiB per input. Design image decode limit 20 MP each / 24 MP total unique decoded images. Photo limit 12 MP and 8192 px per side, 16 MiB processed PNG working data. First frame only; codec support varies by device. |
| PNG | Photo export and new canvas export | New canvas export at 150 or 300 dpi; PNG physical-DPI metadata is not guaranteed. |
| JPEG | Photo export | User-selectable quality; transparency flattened on white. Original file is never overwritten automatically. |
| PDF | New canvas, photo-sheet export and system printing | New canvas PDF is one physical-size page with flattened raster content, not selectable text/vector output. Photo sheet is one page with repeated contain-fitted images. No PDF import, page editing or merge. |
| TXT | Notes export | Plain UTF-8 text, not a rich document. |
| JSON | Business catalogue export | A copy of product records; importing/restoring it in the UI is not implemented. Money is stored in integer hundredths; the UI currently labels amounts TZS and has no currency selector. |
| DOCX, XLSX, CSV, SVG, others | Not implemented | Do not claim compatibility or modification of originals. |

Canvas export is capped at 16 million pixels and 8192 pixels per side; A4 at 300 dpi fits but A3 at 300 dpi does not. Limits reduce, but cannot eliminate, memory failures on every device. Malformed/over-limit inputs are rejected; OS pickers may cache before Dart validates a stream. See [printing](PRINTING.md) and [privacy/security](PRIVACY_AND_SECURITY.md).

Export individual project/notes/catalogue copies to a user-controlled location and verify them. There is no complete suite backup/restore yet. Especially before uninstalling, changing app IDs or switching signing keys, keep the old installation and its data until the exported copies are verified.
