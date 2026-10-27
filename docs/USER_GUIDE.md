# DeskSuite user guide

DeskSuite is a local-first work-in-progress, not a finished office suite. **Getting started** in the navigation has fictional, revisitable exercises; the first welcome can be skipped. No account is required for the local tools described here. Native Android camera, file-picker and print behavior still needs real-device validation for this version.

## Scan pages into an image PDF

1. Open the menu → **Scan & assemble**. Choose **Add image**, **Use camera** on Android, or **Try an example**. The camera opens an installed camera app; its result can be cancelled or rejected if it exceeds the limits. Imports accept PNG, JPEG and WebP, first frame only.
2. Select a page. For a photographed document, select **A4 · portrait**, **A4 · landscape**, **Letter · portrait** or **Letter · landscape** if the paper shape is known. Otherwise leave **Estimate**. Select **Corners & correct** and drag the numbered handles to the paper corners in order (top-left, top-right, bottom-right, bottom-left). Tap a handle or the tune icon to enter coordinates as percentages instead. Select **Correct page**. Correction is manual: there is no automatic edge detection.
3. Select **Clean up & compare**. Choose **Reduce uneven lighting · color** and set lighting strength, or choose **Adaptive black & white** and set mark sensitivity. Select **Preview cleanup**, then **Before** and **After** to compare the current page with that preview. Changing a setting clears the preview; preview again. **Cancel** leaves the draft unchanged; **Use cleaned page** applies the preview to the selected page. Undo the last edit or **Reset page** to return to its orientation-baked imported PNG copy. The separate **Black & white** button still uses a fixed threshold.
4. Rotate, use grayscale and select, reorder or remove pages as needed. Removal asks for confirmation and does not delete the source image.
5. Export an individual **page PNG**, or choose A4 or US Letter paper and **Prepare PDF**. Review the page count and byte size, then choose a **different** destination. Landscape pages use landscape paper; content is contained inside 10 mm margins. Open the saved file in an external PDF reader to check page order and quality.

Lighting cleanup estimates a local paper background and tries to lift shadows while retaining color. It can change photographs, colored paper, artwork or faint writing; adaptive B&W discards color and may lose light text or keep some shadows. Higher sensitivity retains more marks, sometimes including unwanted ones. Transparency is flattened to white. Neither method can recover obscured text. Inspect each preview, and do not use the only copy of an important record as your output destination.

This is an **image-only PDF**: it has no OCR, searchable/selectable text, PDF editing or PDF reader. Paper-proportion correction resamples the image and can distort it if the wrong paper ratio is selected. The final paper size and margins do not establish scan DPI or print accuracy.

The app keeps one private scan draft on the device, including page order and original/edited copies. The draft's “original” is an orientation-baked PNG, not necessarily a byte-for-byte copy of the imported JPEG/WebP or its metadata; the separately selected source file is not automatically modified. A camera app may only provide a temporary capture, so keep an independently saved original when needed. If a write fails, the screen shows **Retry saving draft**; the latest unsaved changes remain in memory and can be exported while the screen remains open. They may be lost if the app/process is closed. If an interrupted camera image is recovered, add it to the draft or export the original before dismissing it. To remove only this draft, choose **Discard draft** and confirm. There is no full backup/restore; export important outputs separately.

## Clean, resize or convert a photo

1. Open **Photo Studio → Choose image**, **Try a sample image**, or **Try a noisy garden photo**. The garden is a synthetic photograph with intentionally added isolated black and white specks. The local source is not changed automatically.
2. For an image of up to **4 megapixels**, choose **Reduce isolated specks**. Pinch the preview to zoom, and select **Compare original** / **Show working copy** to judge the change. This selective local filter only targets strong isolated brightness outliers; it leaves borders and transparent neighborhoods unchanged. It can soften fine details and does not remove scratches, blur or all noise. For larger images, resize a working copy first. A large image's on-screen preview may be downsampled; exported output uses the working image.
3. Choose **Resize**. With **Keep aspect ratio** on, change width and the height follows; the result fits the requested bounds with rounding. For exact independent width and height, turn it off and enter both; the image may be distorted. Enlargement adds interpolated pixels, not new detail. Rotate, flip or centre-square crop if needed. **Undo last edit** and **Reset** affect only the working copy. Replacing an open image asks for confirmation; export it first if needed.
4. Choose **Export PNG** or **Export JPG**. For JPEG, select quality. Review the actual encoded dimensions and byte count, then **Save a copy** to a different destination and open the saved file in an image viewer. Re-encoding may increase size; there is no guaranteed target-size compressor. JPEG removes transparency by flattening onto white.

The Photo working copy is not restored after the app closes. Export it to keep it. Image input is limited to 8 MiB, 12 megapixels and 8192 pixels per side; intermediate encoded files are limited to 16 MiB. The scan draft is limited to 8 pages, 24 megapixels and 32 MiB of processed images (64 MiB for private draft assets). Device memory may be more restrictive.

## Extract text from a photo or scan

1. Open the menu → **Text extraction**. The first card tells you whether the
   offline recognizer is ready on this build. If it is not, the screen says so
   instead of showing an empty result.
2. Choose **Choose image**, or **Use sample letter** to practise. Large images
   are prepared automatically: the real format is verified, EXIF orientation is
   applied and the image is scaled to a 2600 px long edge. The exact size the
   recognizer sees is what the searchable PDF uses.
3. Pick a language: **English** or **English + Kiswahili**, then **Extract text**.
   Recognition runs on the device; nothing is uploaded and no account is needed.
4. Review the text in the editable field. The summary shows the word count and
   the mean confidence; if many words were scored low, a warning asks you to
   check them against the image. Correct anything the recognizer misread.
5. Export: **Save TXT** (UTF-8), **Save DOCX** (a real Word document with one
   paragraph per line) or **Searchable PDF** (the page image plus an invisible
   text layer you can select and search). **Copy** puts the reviewed text on the
   clipboard. Each export goes to a destination you choose; your original image
   is untouched.

Limits you should know: columns, tables and handwriting are not reconstructed —
the text comes out in the recognizer's reading order. The DOCX is a text-flow
document, not a reproduction of the page. The searchable PDF is an image with a
text layer, not an editable PDF. Very large images (over 24 MP or 4000 px) are
refused; recognition accuracy on poor photographs is not guaranteed.

## Convert an office document

1. Open the menu → **Document converter**. Choose a file, or **Use sample
   document** if a sample is bundled in this build.
2. Check the **Detected** row. Detection reads the real container, so a `.docx`
   that is really an ODT is reported as ODT and a renamed file is never trusted.
3. Only routes this build can really run are listed, each with its fidelity. For
   example a DOCX offers PDF, TXT and ODT output; a legacy `.doc` offers nothing
   unless an office engine is installed, and the screen says so.
4. Choose a route and select **Convert**. Review the output name, format, size,
   the engine used and the "What changed" notes.
5. Select **Save output**. The source file is never modified.

What is preserved: paragraph text and order, headings, bold/italic, table rows
and cells, sheet names and values, slide text. What is not: exact fonts, layout,
images, charts, macros, comments, text boxes, number formats and page size (A4 is
used). Layout-faithful rendering needs an installed LibreOffice, which DeskSuite
does not bundle; see the office support notes in the engineering documentation.

## Practise without your own files

- **Getting started → Clean a shadowed page**: open Scan & assemble, choose **Try an example → Shadowed field notes**, preview each cleanup method and compare the text and colored chart before applying. The sample is intentionally degraded, not an official document.
- **Reduce photo specks**: open Photo Studio, choose **Try a noisy garden photo**, reduce specks, zoom and compare with the original. Some specks and fine-detail changes may remain. Both examples use the actual pixel processors; [before/after evidence](engineering/cleanup-evidence.png) shows a host pixel-engine run, not an Android screenshot.
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
