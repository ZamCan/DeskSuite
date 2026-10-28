# DeskSuite user guide

DeskSuite is an actively developed document and creative workspace, not a finished office suite. **Getting started** in the navigation has fictional, revisitable exercises; the first welcome can be skipped. No account is required for the local tools described here. Native Android camera, file-picker and print behavior still needs real-device validation for this version.

## Scan pages into an image PDF

1. Open the menu → **Scan & assemble**. Choose **Add image**, **Use camera** on Android, or **Try an example**. The camera opens an installed camera app; its result can be cancelled or rejected if it exceeds the limits. Imports accept PNG, JPEG and WebP, first frame only.
2. Select a page. For a photographed document, select **A4 · portrait**, **A4 · landscape**, **Letter · portrait** or **Letter · landscape** if the paper shape is known. Otherwise leave **Estimate**. Select **Corners & correct** and drag the numbered handles to the paper corners in order (top-left, top-right, bottom-right, bottom-left). Tap a handle or the tune icon to enter coordinates as percentages instead. Select **Correct page**. Correction is manual: there is no automatic edge detection.
3. Select **Clean up & compare**. Choose **Reduce uneven lighting · color** and set lighting strength, or choose **Adaptive black & white** and set mark sensitivity. Select **Preview cleanup**, then **Before** and **After** to compare the current page with that preview. Changing a setting clears the preview; preview again. **Cancel** leaves the draft unchanged; **Use cleaned page** applies the preview to the selected page. Undo the last edit or **Reset page** to return to its orientation-baked imported PNG copy. The separate **Black & white** button still uses a fixed threshold.
4. Rotate, use grayscale and select, reorder or remove pages as needed. Removal asks for confirmation and does not delete the source image.
5. Export an individual **page PNG**, or choose **Prepare PDF**. Select a shared physical page/media preset (ISO A0–A10, B0–B10, C0–C10, US/ANSI, photo, card/badge, label and poster formats) or enter custom width/height from 20 to 2500 mm. Choose whether page orientation follows each scanned image. Review the page count and byte size, then choose a **different** destination. Content is contained inside 10 mm margins. Large page size does not increase source image detail or guarantee printer support.

Lighting cleanup estimates a local paper background and tries to lift shadows while retaining color. It can change photographs, colored paper, artwork or faint writing; adaptive B&W discards color and may lose light text or keep some shadows. Higher sensitivity retains more marks, sometimes including unwanted ones. Transparency is flattened to white. Neither method can recover obscured text. Inspect each preview, and do not use the only copy of an important record as your output destination.

This scan export is an **image-only PDF**: it has no OCR or searchable/selectable text. For existing-PDF editing, open **PDF Studio** separately. Paper-proportion correction resamples the image and can distort it if the wrong paper ratio is selected. The final paper size and margins do not establish scan DPI or print accuracy.

The app keeps one private scan draft on the device, including page order and original/edited copies. The draft's “original” is an orientation-baked PNG, not necessarily a byte-for-byte copy of the imported JPEG/WebP or its metadata; the separately selected source file is not automatically modified. A camera app may only provide a temporary capture, so keep an independently saved original when needed. If a write fails, the screen shows **Retry saving draft**; the latest unsaved changes remain in memory and can be exported while the screen remains open. They may be lost if the app/process is closed. If an interrupted camera image is recovered, add it to the draft or export the original before dismissing it. To remove only this draft, choose **Discard draft** and confirm. There is no full backup/restore; export important outputs separately.

## Clean, resize or convert a photo

1. Open **Photo Studio → Choose image**, **Try a sample image**, or **Try a noisy garden photo**. The garden is a synthetic photograph with intentionally added isolated black and white specks. The local source is not changed automatically.
2. For an image of up to **4 megapixels**, choose **Reduce isolated specks**. Pinch the preview to zoom, and select **Compare original** / **Show working copy** to judge the change. This selective local filter only targets strong isolated brightness outliers; it leaves borders and transparent neighborhoods unchanged. It can soften fine details and does not remove scratches, blur or all noise. For larger images, resize a working copy first. A large image's on-screen preview may be downsampled; exported output uses the working image.
3. Choose **Resize**. With **Keep aspect ratio** on, change width and the height follows; the result fits the requested bounds with rounding. For exact independent width and height, turn it off and enter both; the image may be distorted. Enlargement adds interpolated pixels, not new detail. Rotate, flip or centre-square crop if needed. **Undo last edit** and **Reset** affect only the working copy. Replacing an open image asks for confirmation; export it first if needed.
4. Choose **Export PNG**, **Export JPG**, or **Optimise & export**. The optimiser can retain original dimensions or choose 120×150, 300×300, 300×400, 600×600, 600×800, 1200×1500 or custom pixel bounds. Preserve aspect ratio by default; switch it off only if exact stretched dimensions are intended. Select JPEG quality, request a percentage reduction, or target a file size in KB. For byte targets, quality is reduced before resolution is reduced. Review actual dimensions, quality and bytes, then **Save a copy**. Targets can be impossible without unacceptable quality loss. The source is never overwritten. The optimiser can export JPEG, a one-image PDF or standalone HTML; PDF is not encrypted and HTML is not PIN-protected.

The Photo working copy is not restored after the app closes. Export it to keep it. Image input is limited to 8 MiB, 12 megapixels and 8192 pixels per side; intermediate encoded files are limited to 16 MiB. The scan draft is limited to 8 pages, 24 megapixels and 32 MiB of processed images (64 MiB for private draft assets). Device memory may be more restrictive.

## Extract text from a photo or scan

1. Open the menu → **Text extraction**. The first card tells you whether the
   text recognizer is available on this build. If it is not, the screen says so
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
images, charts, macros, comments, text boxes, number formats and original page layout. For content-level PDF exports, choose a physical page size from the shared media catalogue or enter custom dimensions. Layout-faithful rendering needs an installed LibreOffice, which DeskSuite does not bundle; see the office support notes in the engineering documentation.

## Create a design, poster, badge or photo sheet

1. Open **Creative Studio** and choose a template or a blank canvas. Choose from the shared media catalogue (ISO A/B/C, US/ANSI, photo paper, business cards, ID-1/CR80 cards, badges, labels and poster/large-format sizes) or enter custom physical dimensions up to 2500 mm per side.
2. Add and edit text, shapes and images. Use **Stamp** for a reusable editable text mark and **Signature** to draw a signature into an image layer. These are design elements, not cryptographic digital signatures or legal signing certificates.
3. Save/reopen the editable .dsdesign project. PNG/PDF exports flatten the artwork. Raster exports are capped at 16 megapixels and 8192 px per side; for large pages the export menu offers lower, clearly labelled DPI options when needed. A lower DPI is a compromise for viewing-distance posters, not close-view photo quality.
4. For repeated photos, open **Photo Sheet** from Photo Studio. Set finished-photo dimensions independently from sheet size. Select paper surface/stock (glossy, satin, matte, plain smooth paper, cardstock, label or poster/banner), and optionally record GSM. This is saved as PDF metadata and is a production note only; choose compatible media in the printer driver. DeskSuite cannot force stock, borderless printing or feed-path support.

## Open and edit an existing PDF

1. Open the menu → **PDF Studio** and choose a supported PDF. To combine files, choose **Combine PDFs**, add at least two PDF files in order, reorder if needed, then export a new combined copy.
2. Review the loaded document and use the available page/content editing tools. Save a **separate copy** rather than overwriting the original.
3. Existing PDF input/output is limited to 48 MiB. Encrypted, malformed, complex or very large PDFs may not open or may use substantial memory. A file-header check does not prove full validity.
4. PDF Studio does not guarantee compatibility with every form, digital signature, annotation, embedded file or advanced PDF feature. Check the saved copy in an independent PDF reader. PDF Studio editing is not a cryptographic signature.
5. **Password/PIN-protected PDF export is not available yet.** A normal PDF or a PIN-only screen is not secure. Do not use the current image/design/scan PDF exports for confidential material requiring document encryption.

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

- **Getting started → Clean a shadowed page**: open Scan & assemble, choose **Try an example → Shadowed field notes**, preview each cleanup method and compare the text and colored chart before applying. The sample is intentionally degraded, not an official document.
- **Reduce photo specks**: open Photo Studio, choose **Try a noisy garden photo**, reduce specks, zoom and compare with the original. Some specks and fine-detail changes may remain. Both examples use the actual pixel processors; [before/after evidence](engineering/cleanup-evidence.png) shows a host pixel-engine run, not an Android screenshot.
- **Getting started → Make a multipage image PDF** opens the scan workspace. Select **Try an example → Two-page report**, reorder it and export.
- **Correct a perspective page** uses the fictional perspective letter. Select A4 portrait and move all four handles; compare with **Reset page**. No corners are detected automatically.
- **Resize an image** uses the synthetic photo and real photo processor. Try width 512 with aspect preserved; review the resulting file.
- **Edit an example design** imports a new editable `.dsdesign` copy. Its text is editable inside DeskSuite; it is not a DOCX document or a word processor.

Other bundled forms, names and invoices are fictional and are not official documents.

## Find other supported routes

Open **Conversion routes** to jump to Photo Studio, Scan & assemble, Files & Projects, Creative Studio, PDF Studio or Notes for an implemented operation. Routes without an engine are marked unavailable. See [conversion details](CONVERSIONS.md) and [formats](FILE_FORMATS.md). Existing PDFs are opened through PDF Studio, not through the scan tool; scan pages remain images in the scan draft.

## Protect your work and troubleshoot

- App-private data is not encrypted by DeskSuite. Clearing app data, uninstalling, switching Android IDs or losing the device can remove it. Export and independently verify copies before changing installations. There is no complete suite backup.
- Exports do not intentionally replace the source, but a system provider can let you choose an existing file. **Choose a new filename/location**; DeskSuite cannot universally prevent an explicit overwrite in an external provider.
- If a file fails to open, check its format and size or try a smaller first-frame image. The native picker or camera can cache data before DeskSuite checks limits. A failed scan save leaves the prior committed draft intact; retry while the current page is still open, or export it.
- Camera, file provider and printer integration depend on Android and external apps. Some providers may use a network. An OS print job or a handoff is not proof of a successful physical print.
- For locally building the application, see [development and signing](DEVELOPMENT.md). This checkout has not passed Android device and signed-release verification.
