# DeskSuite

**Create. Design. Print. Manage.**

DeskSuite is an Android-first, local-first multipurpose creative, office, document-capture, image-editing, print-production and stationery-business workspace by ZamCan (Mussa Fikiri Ngwegelo). PDF is one supported document workflow, not the product's centre. This repository is an actively developed foundation, **not a production-ready suite**. Some core workflows have host-test evidence; native Android behavior, full Office/PDF editing, complete POS and release readiness remain incomplete or unverified.

**Product architecture:** [Unified product and engine integration contract](docs/engineering/UNIFIED_PRODUCT_ARCHITECTURE.md). It defines the shared document/asset engines, one design system, workflow acceptance tests, engine-selection gates and product-wide roadmap. Use it alongside the [master engineering directive](docs/engineering/MASTER_ENGINEERING_DIRECTIVE.md).

## Product areas

DeskSuite is organized around one shared workspace: **Home & Files, Studio, Image Lab, Capture, Office, PDF & Print, and Business**. These are coordinated product areas, not separate mini-apps. They should share projects, asset references, import/export, print services, navigation, design tokens and recovery behavior. The implemented features below are a truthful inventory of the current source, not a claim that all benchmark-product capabilities are complete.

## What you can do in this source tree

- **Scan & assemble:** import PNG/JPEG/WebP or request an Android camera capture; manually correct page perspective, with an optional, reviewable corner suggestion for contrasting bright pages. Preview **Original, Lighten, Reduce shadows, Magic Pro, Grayscale** or adaptive black-and-white and compare before/after. Rotate, reorder up to eight pages, reopen a draft and export A4/US Letter image PDFs or PNG pages. Send the selected working page directly to Text extraction for TXT/DOCX or a searchable single-page PDF. Suggestions and cleanup can be wrong or lose detail; native camera/OCR/provider behavior still needs device verification.
- **Photo Studio:** first-frame PNG/JPEG/WebP input; rotate, flip, crop and resize by pixels or millimetres plus DPI; reduce isolated specks on images up to 4 megapixels; zoom, compare and undo/reset; review output before PNG/JPEG export. The offline optimizer can attempt a target JPEG size and save a JPEG, A4 image PDF or standalone HTML copy; its targets are not guaranteed, and PDF/HTML are not encrypted. Physical sizing does not embed DPI metadata or guarantee calibrated printer output. Speck reduction may soften detail; JPEG flattens transparency to white. Photo sheets do not certify ID requirements.
- **Creative Studio:** editable physical-size designs with text, shapes and images; arrange, edit, undo/redo, autosave/reopen, import/export `.dsdesign`, export PNG or a flattened one-page PDF. Earlier `.dsproject` files can be imported as new copies without automatically changing the source.
- **Office conversion and content editing:** read DOCX/XLSX/PPTX/ODT/ODS/ODP/RTF content and edit readable paragraphs/table cells, then export an edited DOCX/XLSX/ODT/ODS/PDF/TXT/CSV copy. This is not a full Word/Excel layout editor; images, fonts, formulas, macros and complex layout may be lost. Legacy DOC/XLS/PPT and layout-faithful rendering need an external office engine. **Notes, Print and Business:** local plain-text notes and TXT export; A4 print-check PDF and OS print handoff; a stationery catalogue with stock, recorded sales written to `sales.json`, and a real A5 PDF receipt for every sale, printable or exportable. Baskets, refunds, supplier records, expenses, profit reports and tax-compliant invoicing are still missing; the screen says so instead of implying them.
- **Getting started and Conversion routes:** a skippable introduction, revisitable fictional sample tutorials that call the scan/photo/design engines, and an explicit catalogue of supported and unavailable routes. Try the clean, shadowed and angled practice report or the noisy synthetic garden; see the [actual enhancement-engine comparisons](docs/engineering/magic-scan-evidence.png).

Processing is local, without an account, paid API, analytics or cloud requirement. App-private data is **not encrypted by DeskSuite**; uninstalling or clearing data can remove it. Export and independently verify important copies. There is no complete backup/restore.

## Important limits

**Not implemented:** importing/editing existing PDFs, full Word/Excel/PowerPoint editing, layout-faithful Office rendering without an external engine, cloud sync or complete backup/restore. Corner suggestions only address some high-contrast pages and are not automatic cropping. The scanner's multipage PDF remains image-only; OCR processes one selected page and its searchable PDF uses the original recognized words, not text edits. Native picker/camera/print access, process-death recovery, device accessibility, release signing and upgrades remain unverified. DeskSuite does not claim Acrobat, CamScanner, LibreOffice or Microsoft Office parity.

External image picks are bounded to 8 MiB; internal encoded working images can reach 16 MiB. Decoded images are limited to 12 megapixels and 8192 pixels per side; scan output has additional page, byte and pixel limits. External file providers can allow a user to overwrite an existing file: choose a **new destination**. See [user guide](docs/USER_GUIDE.md), [conversion registry](docs/CONVERSIONS.md), [file formats](docs/FILE_FORMATS.md) and [privacy](docs/PRIVACY_AND_SECURITY.md).

## Try the real workflows

1. Open **Getting started** from navigation. For cleanup, try the shadowed practice report or the noisy garden exercises; they call the same local processors as user files.
2. In **Scan & assemble**, choose **Try an example → Shadowed practice report → Clean up & compare**. Preview a method, switch **Before/After**, then apply only if satisfied. Export a separate PNG or an image-only PDF, or choose **Extract text from this page** for the separate OCR workflow.
3. In **Photo Studio**, choose **Try a noisy garden photo → Reduce isolated specks**. Pinch to zoom and compare with the original. Undo or export a separate copy. **Resize** also supports fit-to-bounds or exact independent dimensions.
4. Open **Conversion routes** for supported operations and explicit unsupported routes. The new Flutter UI and native integrations still need the checks in the [validation record](docs/engineering/VALIDATION.md).

More detailed steps and recovery guidance: [user guide](docs/USER_GUIDE.md). Product-owner requirements: [master engineering directive](docs/engineering/MASTER_ENGINEERING_DIRECTIVE.md) and [additional instructions](docs/engineering/OWNER_INSTRUCTIONS.md). Engineering evidence: [current status](docs/engineering/CURRENT_STATUS.md), [baseline audit](docs/engineering/BASELINE_AUDIT.md), [engine evaluation](docs/engineering/ENGINE_EVALUATION.md), [validation record](docs/engineering/VALIDATION.md), [architecture](docs/ARCHITECTURE.md), [roadmap](docs/ROADMAP.md) and [changelog](CHANGELOG.md).

## Develop and build locally

Use your **existing** Flutter, JDK and Android SDK installations. Recorded host checks used Flutter 3.47.8 / Dart 3.13.7. Android's checked-in Gradle 9.3.1 needs a compatible JDK and Android SDK; no Android toolchain was installed for this work. Check out the branch or import the supplied Git bundle if it has not been pushed, then:

```sh
flutter pub get                     # use --offline when already cached
dart test/pixel_algorithms_smoke.dart # standalone pixel checks, no Flutter dependency
dart test/page_corner_pixels_smoke.dart # standalone corner-suggestion checks
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub --concurrency=1 --reporter expanded --timeout 120s
bash tools/build-android.sh debug    # only with your existing Android toolchain
```

A debug APK is for local testing only. For release use a stable private key and local `android/key.properties`, then verify the actual APK/AAB signatures, app ID and behavior on devices. See [development and signing](docs/DEVELOPMENT.md) and [CI](docs/CI.md). **No current signed artifact or installation has been verified.**

The maintained Android application ID remains `com.zamcan.desksuite`. Older prototype builds with ID `com.zamcan.desksuite.desksuite` are separate installations with separate private data; different signing keys also prevent in-place updates. Export and verify backups before uninstalling or migrating.

Repository code: [Apache-2.0](LICENSE). Dependency and sample attribution: [third-party notices](THIRD_PARTY_NOTICES.md). Android native/transitive binary licences must still be reviewed for the actual release.


## Photo Studio: current implementation boundary

The Photo Studio supports local transformations, pixel/physical print sizing, photo-sheet layout presets and **solid-colour placement behind pixels that are already transparent**. The latter is not background removal. Automatic segmentation, mask editing, hair refinement, face/pose detection, authority-verified ID-photo compliance and broad editable template packs are planned and not yet shipped. See [current engineering status](docs/engineering/CURRENT_STATUS.md) and [roadmap](docs/ROADMAP.md).

## Creative Studio starter templates

The shared editable template catalogue currently includes a blank canvas, editorial poster, business card, identity badge, certificate, flyer, an A4 photo print-sheet layout with twenty editable placeholder slots, and a presentation-cover page. These are editable starting layouts using the same design model and export path, not flattened sample images. They are not official identity-card specifications, and a presentation cover is not a multi-slide PPTX deck. See [current status](docs/engineering/CURRENT_STATUS.md) and [roadmap](docs/ROADMAP.md). The added tests have not yet been run in this execution.



The photo print-sheet template is a layout aid: its twenty slots start as editable shapes and text and can be filled one at a time with selected images. Cover fitting crops the image; there is no automatic face alignment or certified passport/ID sizing. Confirm the requirements and printer scaling before use.

### Print production: media and finished sizes are separate

Distinguish finished photo/product dimensions from sheet or roll format, substrate and actual printer support. The app offers physical media dimensions but does not discover printer/stock capabilities. A4/A3 are paper formats, not passport-photo standards. Photo Sheet starts with 4 × 6 inch media and four 35 × 45 mm frames, and shares other media presets with the new-design dialog. Large raster designs need explicitly lower DPI within the pixel budget. Authority-specific sizes must be sourced and scoped; unknown official dimensions remain unspecified. See [Print Production Standards](docs/engineering/PRINT_PRODUCTION_STANDARDS.md) and [printing](docs/PRINTING.md).
