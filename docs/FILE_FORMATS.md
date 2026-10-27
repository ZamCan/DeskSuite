# Files and compatibility

| Format | Current support | Notes |
| --- | --- | --- |
| `.dsdesign` | Create, autosave, reopen, import/export a copy | Version-1 UTF-8 JSON with `format: desksuite.design`, dimensions in mm, ordered objects, styles, and base64-embedded imported images. Import creates a new project ID. 32 MB maximum. |
| `.dsproject` (earlier prototype) | Import as an editable copy | Earlier schema version 1 only; a logical unit becomes 25.4/96 mm, matching that editor's PDF page conversion. Layer order, text, shape colour, positions and eligible embedded images are retained; font rendering and circle appearance can differ. New limits apply, including 8 MB per image and 100 layers. Unknown layers are rejected rather than discarded. Import does not change the source. |
| PNG / JPEG / WebP | Import as an image layer | Original bytes are copied into the project; original files are not overwritten. Each input is limited to 8 MB and 20 megapixels; unique decoded images are limited to 24 megapixels in total. First frame only for animated inputs. Device codec support can vary. |
| PNG | Export | 150 or 300 dpi pixel dimensions calculated from page mm. PNG metadata is not guaranteed to encode physical dpi. |
| PDF | Export | One page, same physical dimensions as the design; content is a flattened raster, not selectable text or vector art. 150/300 dpi. No PDF import/edit/merge. |
| DOCX / XLSX / PPTX / DOC / XLS / PPT / ODT / ODS / ODP / RTF / TXT / HTML / PDF | External handoff only for supported picker extensions | On Android, choose a file and hand it to a compatible installed viewer/editor through a scoped cache URI. This does not provide in-app parsing/editing, conversion, or a guarantee that a compatible app is installed. Source files are not modified. Files are limited to 50 MB for this handoff. |

Export is bounded to 16 million pixels and 8192 pixels per side to reduce memory pressure. A4 at 300 dpi fits; A3 at 300 dpi exceeds the current 16 MP bound and must be exported at 150 dpi. These limits are safeguards, not guarantees against out-of-memory errors on every device. Imported files and project JSON are checked for sizes and unsupported versions; unrecognised or malformed projects are reported, not silently overwritten.

Earlier prototype projects are stored privately by that application and are **not** discovered automatically here. The user must obtain an accessible `.dsproject` copy, choose Import, and verify the result. If the earlier installation uses a different Android application ID, Android isolates its private files; this branch does not migrate data between apps. Keep the earlier app/data and backups until conversion has been verified.
