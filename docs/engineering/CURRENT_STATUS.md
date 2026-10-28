# Master directive — current implementation status

Status of the **source in this repository**, updated 2026-10-28. It is not a
declaration that the whole directive or a release is finished. The full
[master engineering directive](MASTER_ENGINEERING_DIRECTIVE.md) and
[owner instructions](OWNER_INSTRUCTIONS.md) are preserved alongside it; the
[baseline audit](BASELINE_AUDIT.md) describes the starting state and
[validation](VALIDATION.md) records the actual test runs.

## Verification summary

| Check | Result | Where |
| --- | --- | --- |
| Earlier baseline `4c15523` CI | Flutter analyze/test and matrix builds succeeded in the repository's independently running CI | [run 40634495478](https://github.com/ZamCan/DeskSuite/actions/runs/40634495478) |
| Later main `1cef153` CI | Analysis failed on all four jobs; logs require authentication. The feature branch fixes a separately reproduced constant-expression error in that main snapshot, but other project errors cannot be excluded until Flutter runs. | [run 40635793861](https://github.com/ZamCan/DeskSuite/actions/runs/40635793861) |
| New enhancement and corner pixel cores | DartPad 3.13.7 DDC/Node smoke checks passed, including 40 randomized images and synthetic corner/fallback cases | [validation](VALIDATION.md) |
| Media/raster integration | Actual Dart budget and sheet-geometry checks passed for 56 listed presets under DartPad DDC/Node; UI and optimizer control-flow analyses used stubs | [validation](VALIDATION.md) |
| New Flutter codec, widget, OCR-handoff and full-suite tests | **Written, not run in this workspace** | Flutter/Dart tools are absent from this snapshot |
| Android/device and signed release for the new source | **Not built or tested here** | Existing CI was for the earlier baseline only; signing and device checks remain separate |

The baseline CI's successful build steps do not prove a signed release, actual
camera/OCR behavior or the later changes in this feature branch. The owner asked
that no Android toolchain be downloaded or packaging performed in this workspace.

## Earlier implementation slice — Photo print size

Photo Studio offers an **Optimise & export** workflow with offline JPEG optimisation, original/120×150/300×300/300×400/600×600/600×800/1200×1500/custom pixel bounds, quality, reduction-by-percentage and target-KB modes, plus measured preview before saving a copy. JPEG quality is adjusted before resolution is reduced for byte targets, and transparency is flattened onto white. One-image A4 PDF and standalone HTML exports are available; neither is encrypted or access-controlled. These merged/new paths still need the real codec, Flutter suite and Android validation. See [image optimisation and export](IMAGE_OPTIMIZATION_AND_EXPORT.md).

Photo Studio also offers a **Print size** resize mode in addition to pixel dimensions. Users can specify print width/height in millimetres and a target DPI; the shared `lib/images/print_dimensions.dart` engine converts these to pixel dimensions and enforces the 8192-pixel side and 12-megapixel output bounds. Tests were added in `test/print_dimensions_test.dart` for conversion, invalid inputs and pixel-budget enforcement.

This is a source change only until the repository's formatter, analyzer, full host suite and Android build/device checks pass. It does not embed DPI metadata in exported images or guarantee printer calibration.

## Acceptance workflows

| Target | Current result | Missing or unverified |
| --- | --- | --- |
| **A. Paper → searchable PDF** | Camera entry point, optional reviewed corner suggestion, projective correction, enhancement, multipage image PDF, and selected-page handoff to a **single-page searchable PDF** are implemented in source. The original OCR words form the PDF text layer; reviewed edits are exported to TXT/DOCX. | Broad/robust page detection, reviewed edits in PDF text layers, multipage searchable export, in-app PDF reopening, camera and recognition on Android hardware. **Not complete on device.** |
| **B. Image → exact-size output** | Photo Studio supports fit or exact dimensions, print-size/DPI calculation, PNG/JPEG, new offline JPEG target-size optimisation, output review, separate destination, speck reduction, compare and undo. | Percentage resize and embedded DPI metadata; real-world optimizer behavior, device performance, providers and printing are untested for the new source. |
| **C. Existing document → extracted text** | **Implemented in source:** offline Tesseract recognition with English and English+Kiswahili models, EXIF-corrected bounded preparation, editable review, confidence warning, TXT/DOCX export and a searchable PDF. Text is extracted from office documents through the separate converter (below). | Native Android build/device behavior and recognition accuracy on representative photographs and printed pages; handwriting and non-Latin scripts are not supported claims. |
| **D. Convert and compress** | Office reader/writer (DOCX/XLSX/PPTX/ODT/ODS/ODP/RTF/TXT/HTML → PDF/TXT/CSV/ODT/ODS) with per-route fidelity and limits. Image re-encoding with quality control. | Existing-PDF compression and page operations, Office layout-faithful rendering (needs LibreOffice), batch conversion. |
| **E. New-user sample tutorial** | Skippable, revisitable guides plus a sample library; each guide invokes the real engine (scan, cleanup, photo resize, OCR sample letter, office conversion). | Native/device runs of the guides. |

## Modules in this source

- `lib/document_scan/` — camera boundary, optional reviewable bright-page corner
  suggestions and manual fallback, projective processor, Original/Lighten/shadow
  reduction/Magic Pro/grayscale/adaptive B&W preview, image-PDF assembly and private draft.
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
2. Benchmark and improve the limited corner-suggestion heuristic against real
   camera images and difficult lighting, with manual fallback and device profiling.
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


## Historical slice — photo-sheet size examples

The earlier example-only dropdown has since been replaced by editable, source-referenced photo profiles and custom dimensions. Changing either size switches back to Custom. The tool remains a layout aid, not an eligibility, upload or official-acceptance check. See the current profile follow-up below.

Automatic person/pose/head-and-shoulder crop, background removal, editable segmentation masks, automatic authority-compliance validation, broad ID/card/poster/PPTX template packs, and SLM integration remain outstanding.


## Historical slice — photo background placement (2026-10-28)

**Implemented in source**
- Photo Sheet's earlier example-size dropdown was subsequently replaced with source-referenced profiles and Custom; it is still a layout tool, not an automated compliance check.
- Photo Studio offers **Place on background** for images that already contain transparency. It composites the transparent image onto selectable solid colours (white, warm off-white, light grey, pale blue, pale pink, pale green or charcoal), preserves the source image, uses the existing bounded image processor, creates an undoable working-copy edit, and exports an opaque PNG.
- Unit and widget tests were added for alpha compositing, selected background colour, retained foreground pixels, rejection of non-opaque background values, and the Photo Studio import → choose background → export workflow.

**Not implemented by this slice**
- Automatic background removal / segmentation, editable foreground masks, hair-edge refinement, portrait or face detection, head/shoulder auto-crop, pose/landmark SLM guidance, authority-compliance checking, a broad editable template catalogue, or SLM runtime integration.
- The solid-background action does **not** remove a background; it only places existing transparency onto a solid colour. It must not be presented as an automatic passport-photo maker.
- New tests have been written but not run in this execution. Formatter, analyzer, full Flutter suite, CI and Android build/device behavior remain unverified for these latest commits.

## Historical slice — shared editable template catalogue (2026-10-28)

**Implemented in source**
- Added `lib/design/template_catalog.dart` as the single registry for stable template IDs, labels, descriptions and recommended physical dimensions.
- Added seven starter choices: blank canvas, editorial poster, business card, identity badge, certificate, flyer and presentation cover.
- The creation dialog now selects a catalogue entry and builds ordinary `DesignDocument` / `DesignElement` objects. These remain editable in the existing shared editor and use the existing save, render, PDF export and print path; templates are not flattened preview images.
- Added catalogue tests for unique IDs, element bounds and project encode/decode, plus a widget test for choosing and creating a business-card design.

**Scope boundary**
- These are generic starter layouts, not finished template packs, official identity-card specifications, or verified government/school requirements. The later photo-slot action below adds manual replacement for that specific template; general image-frame editing, template thumbnails, user-authored templates, multi-page presentation editing and PPTX export remain unimplemented.
- The new tests have been added but have **not** been run in this execution. Formatter, analyzer, full suite, CI and Android build/device checks remain unverified.

### Registry hardening addendum

The starter registry now records a catalogue schema version, source/provenance label and repository licence for each built-in layout. Template generation rejects non-finite or out-of-range canvas dimensions and bounds generated element geometry for narrow/custom aspect ratios. Added tests cover the metadata and custom-size bounds. These are still source-level changes pending the workflow result; no passing test/build claim is made yet.

## CI follow-up — photo background picker overflow (2026-10-28)

The first matrix run containing the template tests completed formatting and static analysis, and the new template catalogue tests passed. The full suite found one widget failure: a narrow-screen RenderFlex overflow in the photo background picker. The option labels were changed to use a bounded, ellipsized flexible region. The later independent CI run for `4c15523` passed; it does not validate this branch or the subsequently failing `1cef153` main snapshot.



## Historical slice — A4 photo print-sheet template (2026-10-28)

Added a **Photo print sheet** entry to the shared editable template catalogue. It creates an A4 design with twenty 35 × 45 mm example slots arranged in four columns and five rows, plus header/footer guidance. Every slot is made from normal editable rectangle/text elements, so it follows the existing project save/render/export path and does not add a competing layout engine.

**Boundary:** the initial shapes were placeholders rather than automatic image frames. A later manual slot-replacement action is described below; it does not align faces. Dimensions are illustrative, not an official passport/ID standard; users must verify requirements and printer scaling.


## CI follow-up — widget-test timing fixes (2026-10-28)

An earlier Android job reported 176 passing tests and three failures around asynchronous UI timing in navigation, scan-draft retry and unsaved-change recovery. The tests were updated to wait for the Creative Studio scrollable, disappearance of the saved-error state, and presence of the editor action respectively. A later independent run passed for `4c15523`; the feature branch and the subsequent `1cef153` snapshot are separate.


## Photo print-sheet image placement (2026-10-28)

The Creative Studio editor now has a dedicated **Fill photo slot with image** action for a selected catalogue 35 × 45 mm slot. It imports through the existing local file gateway, decodes/validates the image before mutation, replaces the placeholder rectangle and its dimension label with an actual embedded image layer, and records the replacement as one undoable edit. The shared renderer uses cover fitting for image layers so the selected image fills the physical slot; this crops to the frame and does not claim face alignment or biometric compliance. Targeted source tests cover replacement, project serialization, undo and rejection of an ordinary rectangle. Full Flutter/Android validation is still pending.


## Photo-slot editing regression coverage (2026-10-28)

The photo-sheet template test expects 23 text objects: header, subtitle, twenty slot labels and footer. A controller regression test covers replacing one 35 × 45 mm slot, removing its label, reopening image bytes and undo. After a subsequent heading change, these tests now count the exact slot labels rather than every string containing the dimensions. The updated tests have not run in Flutter in this workspace.

## Scan enhancement, corner suggestions and OCR handoff (2026-10-28)

- Added **Original**, global **Lighten**, local **Reduce shadows**, color **Magic Pro**, **Grayscale** and adaptive B&W to the reviewable cleanup dialog. Magic Pro is a bounded classical illumination/contrast heuristic, not an AI model or a promise of shadow removal. Original means the page as it entered the dialog; Reset page returns to the imported orientation-baked PNG copy.
- Added a bounded (≤512 px thumbnail) bright-page corner suggestion. The wand is explicit; detected points may be wrong and must be reviewed before the existing projective correction. Manual dragging/coordinates remain available when no suggestion is found.
- Added clean, shadowed and perspective fictional practice reports plus a real pixel-engine [comparison](magic-scan-evidence.png); the synthetic images are reproducible by `tools/generate_scan_practice.py` and are not camera or Android screenshots.
- Added a direct selected-page handoff from the scan draft to the existing OCR screen. External picks remain capped at 8 MiB; scan working PNGs can use the existing 16 MiB internal bound. Recognition is not automatic. A preparation failure clears the previous source, and users must confirm if a searchable PDF will use uncorrected OCR words after they edit the text. TXT/DOCX keep edits; corrected searchable text and multipage searchable PDFs are not implemented.
- Pixel-core and synthetic sample checks were executed in DDC/Node; Flutter codec/widget/host tests, real-page quality, performance on Android, native OCR/camera, signed builds and device installation are **not verified for these changes**. See [validation](VALIDATION.md).

## Photo-sheet profile and analysis follow-up (2026-10-28)

This branch includes the later main snapshot's Tanzania passport and e-Visa, ICAO guidance, U.S. and Canada profile entries. Their source links and context appear in the sheet dialog, but a layout does not validate or guarantee official acceptance. The dialog states that a PDF print sheet is not an upload file and does not enforce upload limits. Canada explicitly requires professional, unaltered paper photos; the U.S. requires an original unedited photo. The ICAO URL was corrected and its portrait-zone guidance is not presented as a universal submitted-image head-height rule. Users must check current requirements at the linked authority.

The independently running CI for main `1cef153` failed at Flutter analysis; full logs were inaccessible. Separately, analyzing the actual profile registry with DartPad reproduced `const_eval_property_access` on `const ... = photoSpecifications.length`. This branch derives the custom index at runtime and makes the corresponding menu item non-const. Source tests also count exact slot labels instead of the changed heading. Actual project analysis and Flutter tests remain necessary; this is not proof that every cause of the CI failure has been resolved.

## Print-production engineering correction (2026-10-28)

Corrected the product model after review: A4 is a paper format, not a passport-photo standard; 35 × 45 mm is not universal. The general Photo Sheet now starts with 4 × 6 inch (101.6 × 152.4 mm) as a convenient small-format media option while retaining explicit A4/A5/custom choices. The A4 template is labelled as a multi-photo layout example. The authority-scoped Tanzania passport profile remains dimension-unspecified because its cited guideline page does not publish physical width × height; the separate e-Visa upload limits are not treated as passport print dimensions. See [`PRINT_PRODUCTION_STANDARDS.md`](PRINT_PRODUCTION_STANDARDS.md). These source edits require fresh CI and real printer/device verification.

## Media, raster budgets and optimizer reconciliation (2026-10-28)

The branch non-destructively integrates main through `7b15802`, including its poster-DPI choices and card/badge/label presets. The same media catalogue feeds the Photo Sheet and new-design dialog. Custom canvas/template and photo-sheet page geometry now share 10–2500 mm bounds; photo dimensions and the raster budget have independent limits. The 4 × 6 inch sheet starts with four copies, and selecting or manually entering a custom design size no longer shows the final catalogue preset by mistake.

The design exporter retains explicit lower choices from main and adds a calculation for the highest whole-number DPI at or below 150 that fits the 16 MP/8192-pixel budget. Lower DPI and non-embedded PNG print size are disclosed; these limits cannot guarantee device memory, printer support or adequate detail. The optimizer now composites transparent pixels onto white before resizing, accepts bounded internal working images up to 16 MiB, and wraps its JPEG on an A4 image-only PDF rather than treating pixels as PDF points. Its PDF and HTML are not encrypted. Source tests were added for the new paths and synthetic checks are documented in [validation](VALIDATION.md); real codec, Flutter/widget, system print and Android tests remain outstanding.
