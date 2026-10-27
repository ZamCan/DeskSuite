# DeskSuite user guide

DeskSuite is a local-first work-in-progress, not a finished office suite. **Getting started** in the navigation has fictional, revisitable exercises; the first welcome can be skipped. No account is required for the local tools described here. Native Android camera, file-picker and print behavior still needs real-device validation for this version.

## Scan pages into an image PDF

1. Open the menu → **Scan & assemble**. Choose **Add image**, **Use camera** on Android, or **Try an example**. The camera opens an installed camera app; its result can be cancelled or rejected if it exceeds the limits. Imports accept PNG, JPEG and WebP, first frame only.
2. Select a page. For a photographed document, select **A4 · portrait**, **A4 · landscape**, **Letter · portrait** or **Letter · landscape** if the paper shape is known. Otherwise leave **Estimate**. Select **Corners & correct** and drag the numbered handles to the paper corners in order (top-left, top-right, bottom-right, bottom-left). Tap a handle or the tune icon to enter coordinates as percentages instead. Select **Correct page**. Correction is manual: there is no automatic edge detection.
3. Rotate or apply grayscale/black-and-white. Color is the initial image; use undo or reset to return to an earlier color copy. Use the page controls to select, reorder or remove pages. Removal asks for confirmation and does not delete the source image.
4. Choose A4 or US Letter paper and **Prepare PDF**. Review the page count and byte size, then choose a **different** destination. Landscape pages use landscape paper; content is contained inside 10 mm margins. Open the saved file in an external PDF reader to check page order and quality.

This is an **image-only PDF**: it has no OCR, searchable/selectable text, PDF editing or PDF reader. Paper-proportion correction resamples the image and can distort it if the wrong paper ratio is selected. The final paper size and margins do not establish scan DPI or print accuracy.

The app keeps one private scan draft on the device, including page order and original/edited copies. If a write fails, the screen shows **Retry saving draft**; the latest unsaved changes remain in memory and can be exported while the screen remains open. They may be lost if the app/process is closed. If an interrupted camera image is recovered, add it to the draft or export the original before dismissing it. To remove only this draft, choose **Discard draft** and confirm. There is no full backup/restore; export important outputs separately.

## Resize or convert a photo

1. Open **Photo Studio → Choose image**, or **Try a sample image** for a synthetic practice photograph. The local source is not changed automatically.
2. Choose **Resize**. With **Keep aspect ratio** on, change width and the height follows; the result fits the requested bounds with rounding. For exact independent width and height, turn it off and enter both; the image may be distorted. Enlargement adds interpolated pixels, not new detail. Rotate, flip or centre-square crop if needed. **Compare original**, **Undo last edit**, and **Reset** affect only the working copy.
3. Choose **Export PNG** or **Export JPG**. For JPEG, select quality. Review the actual encoded dimensions and byte count, then **Save a copy** to a different destination and open the saved file in an image viewer. Re-encoding may increase size; there is no guaranteed target-size compressor. JPEG removes transparency by flattening onto white.

The Photo working copy is not restored after the app closes. Export it to keep it. Image input is limited to 8 MiB, 12 megapixels and 8192 pixels per side; intermediate encoded files are limited to 16 MiB. The scan draft is limited to 8 pages, 24 megapixels and 32 MiB of processed images (64 MiB for private draft assets). Device memory may be more restrictive.

## Practise without your own files

- **Getting started → Make a multipage image PDF** opens the scan workspace. Select **Try an example → Two-page report**, reorder it and export.
- **Correct a perspective page** uses the fictional perspective letter. Select A4 portrait and move all four handles; compare with **Reset page**. No corners are detected automatically.
- **Resize an image** uses the synthetic photo and real photo processor. Try width 512 with aspect preserved; review the resulting file.
- **Edit an example design** imports a new editable `.dsdesign` copy. Its text is editable inside DeskSuite; it is not a DOCX document or a word processor.

Other bundled forms, names and invoices are fictional and are not official documents.

## Find other supported routes

Open **Conversion routes** to jump to Photo Studio, Scan & assemble, Files & Projects, Creative Studio or Notes for an implemented operation. Routes without an engine are marked unavailable. See [conversion details](CONVERSIONS.md) and [formats](FILE_FORMATS.md). Existing PDFs cannot be opened, merged or compressed by the scan tool; existing pages are **images in the scan draft**, not pages imported from a PDF.

## Protect your work and troubleshoot

- App-private data is not encrypted by DeskSuite. Clearing app data, uninstalling, switching Android IDs or losing the device can remove it. Export and independently verify copies before changing installations. There is no complete suite backup.
- Exports do not intentionally replace the source, but a system provider can let you choose an existing file. **Choose a new filename/location**; DeskSuite cannot universally prevent an explicit overwrite in an external provider.
- If a file fails to open, check its format and size or try a smaller first-frame image. The native picker or camera can cache data before DeskSuite checks limits. A failed scan save leaves the prior committed draft intact; retry while the current page is still open, or export it.
- Camera, file provider and printer integration depend on Android and external apps. Some providers may use a network. An OS print job or a handoff is not proof of a successful physical print.
- For locally building the application, see [development and signing](DEVELOPMENT.md). This checkout has not passed Android device and signed-release verification.
