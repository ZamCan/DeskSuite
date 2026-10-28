# Master directive — current implementation status

Status of the **source in this repository**, recorded 2026-10-27. It is not a
declaration that the whole directive or a release is finished. The full
[master engineering directive](MASTER_ENGINEERING_DIRECTIVE.md) and
[owner instructions](OWNER_INSTRUCTIONS.md) are preserved alongside it; the
[baseline audit](BASELINE_AUDIT.md) describes the starting state and
[validation](VALIDATION.md) records the actual test runs.

## Verification summary

| Check | Result | Where |
| --- | --- | --- |
| `flutter test` (host, Linux, `--concurrency=1`) | **152 passed** | [validation](VALIDATION.md) |
| `flutter analyze` | no issues | same |
| `dart format --set-exit-if-changed` | clean | same |
| `dart test/pixel_algorithms_smoke.dart` | PASS | same |
| Android release build | **not built here** | Deferred to GitHub Actions or an offline Termux build, by owner instruction. |

Two failures reported by GitHub Actions on an earlier commit were diagnosed and
fixed in this tree: `TessBaseAPI.end()` does not exist (the engine is released
with `recycle()`), and a Windows-only widget test waited a fixed number of pump
rounds for an image to decode.

## Latest implementation slice

Photo Studio now offers a **Print size** resize mode in addition to pixel dimensions. Users can specify print width/height in millimetres and a target DPI; the shared `lib/images/print_dimensions.dart` engine converts these to pixel dimensions and enforces the 8192-pixel side and 12-megapixel output bounds. Tests were added in `test/print_dimensions_test.dart` for conversion, invalid inputs and pixel-budget enforcement.

This is a source change only until the repository's formatter, analyzer, full host suite and Android build/device checks pass. It does not embed DPI metadata in exported images or guarantee printer calibration.

## Acceptance workflows

| Target | Current result | Missing or unverified |
| --- | --- | --- |
| **A. Paper → searchable PDF** | Camera entry point, manual corners, projective correction, tone/rotation, multipage ordering, image PDF, and now **OCR text layer** (searchable PDF) are implemented. The text layer is verified by inflating the generated PDF and asserting each recognized word is present. | Automatic edge detection, in-app PDF reopening, camera and recognition behaviour on Android hardware. **Not complete on device.** |
| **B. Image → exact-size output** | Photo Studio: fit or exact independent dimensions, PNG/JPEG, quality, output review, separate destination, speck reduction, compare, undo. Verified by decoding the exported file and asserting dimensions. | Percentage and physical-DPI resizing. Native provider behaviour untested. |
| **C. Existing document → extracted text** | **Implemented.** Offline Tesseract recognition with English and English+Kiswahili models, EXIF-corrected bounded preparation, editable review, confidence warning, TXT/DOCX export and a searchable PDF. Text is extracted from documents through the separate converter (below). | Recognition accuracy on real photographs and printed pages, handwriting, and non-Latin scripts. |
| **D. Convert and compress** | Office reader/writer (DOCX/XLSX/PPTX/ODT/ODS/ODP/RTF/TXT/HTML → PDF/TXT/CSV/ODT/ODS) with per-route fidelity and limits. Image re-encoding with quality control. | Existing-PDF compression and page operations, Office layout-faithful rendering (needs LibreOffice), batch conversion. |
| **E. New-user sample tutorial** | Skippable, revisitable guides plus a sample library; each guide invokes the real engine (scan, cleanup, photo resize, OCR sample letter, office conversion). | Native/device runs of the guides. |

## Modules in this source

- `lib/document_scan/` — camera boundary, manual corners, projective processor,
  lighting and adaptive B&W cleanup, preview, image-PDF assembly, private draft.
- `lib/images/` — bounded photo decoding, resize/rotate/crop, selective speck
  reduction, cleanup pixel engine.
- `lib/ocr/` — Tesseract boundary, image preparation, searchable PDF builder,
  TXT/DOCX exports, extraction screen. Native bridge in
  `android/.../OcrChannel.kt`; models in `assets/tessdata/`.
- `lib/office/` — format detection, bounded package reader, OOXML/ODF/RTF
  readers, PDF renderer with an embedded Unicode font, ODT/ODS writers,
  conversion registry with an external-engine seam, converter screen. See
  [office support](OFFICE_SUPPORT.md).
- `lib/workspace/` — workspace shell, project repository, file gateway and
  document picker, conversion catalogue, getting-started guides.
- `lib/design/`, `lib/printing/`, `lib/business/`, `lib/legacy_studios.dart` —
  creative editor, exports, photo sheets and printing, inventory/POS, and the
  restored studio screens.

## Release and signing

The application ID remains `com.zamcan.desksuite`. No keystore, password or
signing secret is committed. `docs/CI.md` documents the exact secret names and
the release job signs only when they are present; unsigned validation artifacts
are labelled as such. No signed APK/AAB has been produced or installed from this
environment.

## Next bounded stage

1. Verify the first Android build from CI (or an offline Termux build) and
   install it, then run the scanner, OCR and converter against real documents.
2. Add automatic document edge detection with a manual fallback, and page preview
   for imported photo pages.
3. PDF import: render pages, extract existing text, reorder/split/compress —
   the largest remaining gap for "Acrobat-style" workflows.
4. **Done for sales:** `lib/business/sale_receipt.dart` turns a recorded sale into
   a real A5 PDF receipt, and `InventoryRepository.recordSale` keeps a numbered
   `sales.json` log so it can be reprinted. Next in this area: multi-item
   baskets, quotations/invoices with customer details, refunds, supplier records
   and expenses — none of which exist yet.

## Open agent branches and how each was judged

Five pull requests were open against this repository while the above work landed.
They were written in parallel and each is based on an older `main`, so no branch
is merged on the strength of its description. Each was compared with `main`
before deciding.

| Branch / PR | What it adds | Decision |
| --- | --- | --- |
| `engineering/office-content-editor` (#5) | Offline editing of an opened office document's text content, reachable from the converter, with writer support and tests. | **Merged** into `main` at `7639844`. It fills a real gap (editing) without duplicating an engine. The branch's copy of `test/scan_studio_widget_test.dart` was dropped in favour of the version on `main`, which waits for controls to be enabled; the app-side scan changes merged cleanly. Verified here: analyze clean, 156/156 host tests. |
| `engineering/engine-capability-audit` (#3) | `ImageProcessingService` (263 lines), a Photo Studio screen, a PDF Studio screen, and audit/selection documents. | **Not merged.** The image service is a second image engine beside `lib/images/photo_processor.dart`, which already does bounded decode, crop, rotate, exact-pixel resize and JPEG quality with tests; the directive forbids competing engines for one task. Its PDF screen is better taken from #6, which is a dedicated PDF implementation. Useful ideas remain in its `ENGINE_SELECTION.md`; a reviewer should re-cut the parts that are genuinely new rather than merge the branch whole. |
| `engineering/pdf-studio-editor` (#6) | A PDF Studio screen for existing PDFs plus conversion-catalogue and navigation wiring, with its own tests. | **Candidate next.** This is the largest honest gap: `main` currently declares "existing PDF → images/pages/compressed PDF" explicitly unavailable. Needs the same treatment as #5: merge, keep `main`'s scan test harness, then run the full suite before any claim. |
| `engineering/scan-studio-ci-fixes` (#4) | Scan recovery readiness plus a rewritten scan test file. | **Superseded in part.** `main` already fixes the failures at their cause (tapping disabled controls) and its scan tests are green. Review the app-side recovery change; do not reintroduce the older test harness. |
| `engineering/document-workflows-phase-1` (#2) | Earlier image tools, stamps, signatures and brand foundation. | **Historical.** Its content is largely present in `main` by another route; close it after a manual comparison rather than merging. |

Nothing in this table is a claim that an unmerged branch works.


## Latest implementation slice — editable photo-sheet size presets

The existing Photo Sheet dialog now offers editable example sizes (35 × 45 mm, 50.8 × 50.8 mm, 30 × 40 mm and 40 × 50 mm) in addition to custom dimensions. Editing either dimension switches the selector to Custom. The dialog explicitly warns that these are layout examples, not universal or official passport/ID requirements. This extends the existing shared physical print-sheet engine rather than creating a second photo-layout implementation.

**Not yet implemented by this slice:** automatic person/pose/head-and-shoulder crop, background removal or replacement, editable segmentation masks, country/authority-specific verified presets, broad ID/card/poster/PPTX template packs, or SLM integration. These are now explicit in the master directive and roadmap and require engine/licence/performance evaluation and real workflow tests. This source change has not yet been run through Flutter format/analyze/tests or an Android build.


## Latest implementation slice — photo background placement and size presets (2026-10-28)

**Implemented in source**
- Photo Sheet offers editable example dimensions (35 × 45 mm, 50.8 × 50.8 mm, 30 × 40 mm and 40 × 50 mm), plus Custom. These are layout examples only, not authority-verified requirements.
- Photo Studio offers **Place on background** for images that already contain transparency. It composites the transparent image onto selectable solid colours (white, warm off-white, light grey, pale blue, pale pink, pale green or charcoal), preserves the source image, uses the existing bounded image processor, creates an undoable working-copy edit, and exports an opaque PNG.
- Unit and widget tests were added for alpha compositing, selected background colour, retained foreground pixels, rejection of non-opaque background values, and the Photo Studio import → choose background → export workflow.

**Not implemented by this slice**
- Automatic background removal / segmentation, editable foreground masks, hair-edge refinement, portrait or face detection, head/shoulder auto-crop, pose/landmark SLM guidance, verified country/authority presets, a broad editable template catalogue, or SLM runtime integration.
- The solid-background action does **not** remove a background; it only places existing transparency onto a solid colour. It must not be presented as an automatic passport-photo maker.
- New tests have been written but not run in this execution. Formatter, analyzer, full Flutter suite, CI and Android build/device behavior remain unverified for these latest commits.

## Latest implementation slice — shared editable template catalogue (2026-10-28)

**Implemented in source**
- Added `lib/design/template_catalog.dart` as the single registry for stable template IDs, labels, descriptions and recommended physical dimensions.
- Added seven starter choices: blank canvas, editorial poster, business card, identity badge, certificate, flyer and presentation cover.
- The creation dialog now selects a catalogue entry and builds ordinary `DesignDocument` / `DesignElement` objects. These remain editable in the existing shared editor and use the existing save, render, PDF export and print path; templates are not flattened preview images.
- Added catalogue tests for unique IDs, element bounds and project encode/decode, plus a widget test for choosing and creating a business-card design.

**Scope boundary**
- These are generic starter layouts, not finished template packs, official identity-card specifications, or verified government/school requirements. Logo/photo placeholders, image-frame editing, template thumbnails, user-authored templates, multi-page presentation editing and PPTX export are not implemented by this slice.
- The new tests have been added but have **not** been run in this execution. Formatter, analyzer, full suite, CI and Android build/device checks remain unverified.

### Registry hardening addendum

The starter registry now records a catalogue schema version, source/provenance label and repository licence for each built-in layout. Template generation rejects non-finite or out-of-range canvas dimensions and bounds generated element geometry for narrow/custom aspect ratios. Added tests cover the metadata and custom-size bounds. These are still source-level changes pending the workflow result; no passing test/build claim is made yet.

