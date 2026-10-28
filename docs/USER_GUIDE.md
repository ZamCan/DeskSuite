# DeskSuite user guide

DeskSuite is a local-first work-in-progress, not a finished office suite. **Getting started** in the navigation has fictional, revisitable exercises; the first welcome can be skipped. No account is required for the local tools described here. Native Android camera, file-picker and print behavior still needs real-device validation for this version.

## Scan pages into an image PDF

1. Open the menu → **Scan & assemble**. Choose **Add image**, **Use camera** on Android, or **Try an example**. The camera opens an installed camera app; its result can be cancelled or rejected if it exceeds the limits. Imports accept PNG, JPEG and WebP, first frame only.
2. Select a page. For a photographed document, select **A4 · portrait**, **A4 · landscape**, **Letter · portrait** or **Letter · landscape** if the paper shape is known. Otherwise leave **Estimate**. Select **Corners & correct**. The wand can suggest corners for a bright page on a darker contrasting background; it may find the wrong object or no page. Always check and drag the numbered handles to the actual corners in order (top-left, top-right, bottom-right, bottom-left). Tap a handle or the tune icon to enter percentages. Nothing is cropped until you select **Correct page**.
3. Select **Clean up & compare**. Choose **Original** (the current page), **Lighten**, **Reduce shadows**, **Magic Pro · clean color**, **Grayscale** or **Adaptive black & white**. Adjust strength or mark sensitivity where available. Select **Preview cleanup**, then **Before** and **After**; changing a setting clears the preview. **Cancel** leaves the draft unchanged; **Use cleaned page** applies the preview. Original keeps the current working page, while **Reset page** returns to the orientation-baked imported PNG copy. The separate **Black & white** button uses a fixed threshold.
4. Rotate and select, reorder or remove pages as needed. Removal asks for confirmation and does not delete the source image. For OCR, select a page and choose **Extract text from this page**; recognition remains a separate explicit action.
5. Export an individual **page PNG**, or choose A4 or US Letter paper and **Prepare PDF**. Review the page count and byte size, then choose a **different** destination. Landscape pages use landscape paper; content is contained inside 10 mm margins. Open the saved file in an external PDF reader to check page order and quality.

**Lighten** brightens the whole image; **Reduce shadows** tries a milder local correction; **Magic Pro** combines local paper normalization and a contrast curve. These are deterministic image-processing heuristics, not AI restoration, and do not guarantee shadow-free pages. They can change photographs, colored paper, artwork or faint writing. Adaptive B&W discards color; higher sensitivity retains more marks, sometimes including shadows. Original preserves transparency; the other modes flatten it to white. None can recover obscured text. Inspect each preview and save to a new destination.

This is an **image-only PDF**: it has no OCR, searchable/selectable text, PDF editing or PDF reader. Paper-proportion correction resamples the image and can distort it if the wrong paper ratio is selected. The final paper size and margins do not establish scan DPI or print accuracy.

The app keeps one private scan draft on the device, including page order and original/edited copies. The draft's “original” is an orientation-baked PNG, not necessarily a byte-for-byte copy of the imported JPEG/WebP or its metadata; the separately selected source file is not automatically modified. A camera app may only provide a temporary capture, so keep an independently saved original when needed. If a write fails, the screen shows **Retry saving draft**; the latest unsaved changes remain in memory and can be exported while the screen remains open. They may be lost if the app/process is closed. If an interrupted camera image is recovered, add it to the draft or export the original before dismissing it. To remove only this draft, choose **Discard draft** and confirm. There is no full backup/restore; export important outputs separately.

## Clean, resize or convert a photo

1. Open **Photo Studio → Choose image**, **Try a sample image**, or **Try a noisy garden photo**. The garden is a synthetic photograph with intentionally added isolated black and white specks. The local source is not changed automatically.
2. For an image of up to **4 megapixels**, choose **Reduce isolated specks**. Pinch the preview to zoom, and select **Compare original** / **Show working copy** to judge the change. This selective local filter only targets strong isolated brightness outliers; it leaves borders and transparent neighborhoods unchanged. It can soften fine details and does not remove scratches, blur or all noise. For larger images, resize a working copy first. A large image's on-screen preview may be downsampled; exported output uses the working image.
3. Choose **Resize** and select **Pixels**, **Print size** or **Percentage**. Percentage is measured against the current working copy, from 1% to 1000%; a live preview shows rounded output dimensions. With **Keep aspect ratio** on, change width and the height follows; for independently specified dimensions, turn it off, which can distort the image. Choose nearest-neighbour, linear or cubic resampling. Cubic may take longer; enlargement does not create new detail. Very small results are rounded to at least one pixel per side. Rotate, flip or centre-square crop if needed. **Undo last edit** and **Reset** affect only the working copy. Replacing an open image asks for confirmation; export it first if needed.
4. Choose **Export PNG** or **Export JPG**. For JPEG, select quality. Review the actual encoded dimensions and byte count, then **Save a copy** to a different destination and open the saved file in an image viewer. Re-encoding can increase size. JPEG removes transparency by flattening onto white.
5. For a desired byte size, choose **Optimise & export**. Select a pixel box and either JPEG quality, a percentage reduction from the current working image, or a target KB. Preview the actual output and save a copy. A target can be impossible within the safety limits. PDF output fits the image on A4 with 10 mm margins and is not encrypted; HTML embeds the image and is not access-controlled. These exports do not certify a passport photograph or a physical print size.

The Photo working copy is not restored after the app closes. Export it to keep it. Image input is limited to 8 MiB, 12 megapixels and 8192 pixels per side; intermediate encoded files are limited to 16 MiB. The scan draft is limited to 8 pages, 24 megapixels and 32 MiB of processed images (64 MiB for private draft assets). Device memory may be more restrictive.

### Photo-sheet profiles and official submissions

The Photo Sheet dialog offers custom dimensions and source-referenced examples. Read the scope, notes and authority link for the selected profile: specifications can change and the layout is not a compliance check. The Tanzania e-Visa entry describes an upload rule, but the sheet tool creates a print/PDF layout, **not** a JPG upload or an upload-size guarantee. For Canadian in-person/mail passport applications, the linked government guidance requires original, unaltered photos taken and professionally printed by a commercial photographer or studio; it does not accept home printing or photo edits. The U.S. paper-photo guidance also requires an unedited original. Do not apply document-enhancement modes to official ID photos unless the issuing authority allows it.

## Export or print a design

In the Creative Studio editor choose **Export design**. Normal pages can use 150 or 300 dpi when they fit the pixel budget. For a large canvas, the menu offers a clearly labelled lower-DPI PDF, PNG or print option and, where applicable, further 100/72/60/36 dpi PDF/PNG choices. Lower raster resolution can make small text and detail soft. PDF preserves the physical page size but is flattened; PNG does not reliably carry the intended physical print size. Confirm the paper, printer scale and output in a separate viewer or measured test print. See [printing limits](PRINTING.md).

## Extract text from a photo or scan

1. Open the menu → **Text extraction**, or choose **Extract text from this page**
   for the selected working page in Scan & assemble. The first card tells you
   whether the offline recognizer is ready on this build. If it is not, the screen
   says so instead of showing an empty result.
2. If no scan page was passed in, choose **Choose image**, or **Use sample letter** to practise. Large images
   are prepared automatically: the real format is verified, EXIF orientation is
   applied and the image is scaled to a 2600 px long edge. The exact size the
   recognizer sees is what the searchable PDF uses.
3. Pick a language: **English** or **English + Kiswahili**, then **Extract text**.
   Recognition runs on the device; nothing is uploaded and no account is needed.
4. Review the text in the editable field. The summary shows the word count and
   the mean confidence; if many words were scored low, a warning asks you to
   check them against the image. Correct anything the recognizer misread.
5. Export: **Save TXT** (UTF-8) or **Save DOCX** (a real Word document with one
   paragraph per line) includes your reviewed edits. **Searchable PDF** contains
   the image plus an invisible layer of the *original recognized words and
   positions*, not your edits; if you changed the text, a confirmation warns you.
   **Copy** puts reviewed text on the clipboard. Choose a new destination; your
   original image is untouched.

Limits you should know: columns, tables and handwriting are not reconstructed —
the text comes out in the recognizer's reading order. The DOCX is a text-flow
document, not a reproduction of the page. The searchable PDF is an image with a
text layer, not an editable PDF. External image picks are limited to 8 MiB;
internal scan PNGs can be up to 16 MiB, and image decoding is limited to 12 MP
and 8192 px per side before downsampling. Recognition accuracy on poor
photographs is not guaranteed.

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

## Sell something and print a receipt

1. Open the menu → **Business & POS**. The screen lists your products with their
   price and current stock; the header shows the stock value at listed prices.
2. Choose **Add product**, enter a name, a price such as `125.50` and the opening
   stock, then **Add**.
3. Select the sale button on a product row to sell one unit. Stock goes down, the
   sold counter goes up, the sale is written to `sales.json` on this device, and
   a message shows the amount with a **Receipt** action.
4. Choose **Receipt**. DeskSuite renders a real A5 PDF with your shop name,
   receipt number, date and time, the item, quantity, unit price, line total and
   grand total, then opens the system print dialog so you can print or save it.
5. Receipt numbers are sequential and never reused, so a later sale cannot
   overwrite an earlier one.

What the receipt is not: the page itself says it is an internal sales receipt,
not a tax invoice or a fiscal receipt. DeskSuite does not compute VAT, does not
connect to a fiscal device, and does not manage refunds, suppliers or expenses
yet. Selling more than the stock on hand is refused and changes nothing.

## Practise without your own files

- **Getting started → Clean a shadowed page**: open Scan & assemble, choose **Try an example → Shadowed practice report**, preview each cleanup method and compare the text and colored bars before applying. The separate **Clean practice report** is the fictional unshaded reference. [Comparison evidence](engineering/magic-scan-evidence.png) shows actual Dart pixel output, not an Android screenshot.
- **Reduce photo specks**: open Photo Studio, choose **Try a noisy garden photo**, reduce specks, zoom and compare with the original. Some specks and fine-detail changes may remain. [Earlier evidence](engineering/cleanup-evidence.png) shows the pixel engine, not an Android screenshot.
- **Getting started → Make a multipage image PDF** opens the scan workspace. Select **Try an example → Two-page report**, reorder it and export.
- **Correct a perspective page** uses the fictional angled practice report. Select A4 portrait and try the corner-suggestion wand or adjust the handles manually. Check all four before applying and compare with **Reset page**.
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
