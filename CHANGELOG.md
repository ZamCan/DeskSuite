# Changelog

## Unreleased — artwork mapped to real sections (not a release)

- Connected each of the six Home cards, navigation rows and section headers to a single section-to-art mapping; guide artwork remains matched to its actual action. The design with the ruler and pencil now identifies Creative Studio, while the simpler document/DS candidate identifies Text extraction.
- Replaced the manually ordered `IndexedStack` child list with a keyed, exhaustive section-to-page switch. This preserves lazy page construction while making new unmapped sections a compile-time error. It does not integrate the independently advanced main-branch PDF work.
- Ten host brand/mapping tests passed, and the actual artwork map and section switch passed DartPad DDC/Node tests for 13 pages, lazy states, guide/conversion routing and picker forwarding using UI stubs. New Flutter interaction tests remain unrun; no real device or desktop build was tested.

## Unreleased — selected desktop icon and section artwork (not a release)

- Kept the owner's chosen blue dimensional DS scan-frame PNG as the single app logo. Generated a multi-resolution Windows ICO from it, placed it in the default runner resource path, and configured the Linux AppImage icon to use the same selected mark. A user-local Linux desktop launcher installer is available; platform builds and visual appearance remain unverified.
- Reused six earlier candidates as decorative artwork for actionable Home tool cards, section title bars and relevant guide cards, without replacing the logo. Added source assets, reproducible thumbnail generation, accessibility/fallback handling and Flutter tests; actual widget/device tests remain unrun.
- Eight host brand-asset tests passed, including pixel-for-pixel checks of every ICO frame and static Home-card wiring; three user-local Linux launcher tests passed, including launching a fictional executable through GIO with a quoted path. Targeted DartPad analyses passed with project dependencies stubbed. This is not evidence of an actual desktop or Android build.

## Unreleased — branded launch and experimental Office preview (not a release)

- Added a reduced-motion-aware startup drawing/pulsing the scan frame into the selected DS logo, plus the mark on welcome and guide screens. DartPad analyzed the launch code and the motion geometry smoke passed; Flutter widget/device tests are unrun.
- Added an Android-only, **disabled-by-default experimental** read-only Office preview backed by real OpenDocument.core 7.6.1 C++/WASM, not content extraction. One genuine DOC/DOCX/XLS/XLSX/PPT/PPTX fixture each produced HTML containing expected text under Node; this does not validate Android, visual fidelity or offline isolation. It is not conversion/editing. Collected notices and corresponding source are included; release licence audit remains outstanding.
- Added ZIP preflight before the archive decoder and explicit CRC checks, and corrected false LibreOffice/Termux integration claims. DartPad/Node exercised the preflight including 3,000 mutations and three real OOXML fixture structures. New real-archive/Flutter tests are written but unrun. See [Office support](docs/engineering/OFFICE_SUPPORT.md).

## Unreleased — selected identity and engine hardening (not a release)

- Applied the owner's selected dimensional DS icon to the in-app brand and Android launcher resources; added simplified vector splash/themed-icon adaptations, coordinated sapphire light/dark colors and home shortcuts to the existing scan, photo, OCR and converter workflows. Actual Android rendering and the new Flutter widget tests remain unverified.
- Improved target-size JPEG optimization for very wide/tall images and calculate resize attempts from the initial target, sampling the same original opaque raster to avoid cumulative resampling. Targets remain bounded and can be impossible. Codec tests are written but unrun.
- Short-circuited zero-strength color cleanup without changing its alpha-compositing behavior. DDC/Node compared the old and new pixel output exactly on 100 randomized images per color mode; grayscale and B&W remain active at zero. See [validation](docs/engineering/VALIDATION.md).

## Unreleased — placed-image print warning (not a release)

- Corrected Creative Studio's effective image-resolution estimate to match its cropped **cover** rendering, avoiding overstatement for mismatched aspect ratios. Photo-sheet estimates retain their **contain** behavior. The pure geometry passed 5,000 deterministic DartPad/Node cases and the actual warning calculation passed with stub images; Flutter rendering and warning tests remain unrun.

## Unreleased — photo resize controls (not a release)

- Added percentage resizing relative to the current working image, with rounded-dimension preview and bounded 1–1000% input. Added nearest, linear and cubic resampling to the existing photo engine; palette images are expanded when required so linear/cubic are not silently replaced with nearest-neighbour.
- Fixed parsing of hidden pixel fields when switching to print-size mode and avoided a second proportional fit that could lose pixels after rounding. Percentage geometry and processor control flow passed DartPad/Node checks (the latter with a simulated codec); real codec and widget regression tests are written but unrun. See [validation](docs/engineering/VALIDATION.md).

## Unreleased — shared media and optimizer reconciliation (not a release)

- Non-destructively integrated newer main work for poster export, shared media and card/badge/label sizes. Corrected the custom-size selection and aligned design/template/sheet page bounds to 10–2500 mm; the default 4 × 6 inch photo sheet now fits its four photos.
- Large pages can choose an explicitly labelled pixel-budget-fitting raster DPI plus eligible 100/72/60/36 dpi PDF/PNG options. The PDF page remains physically sized; PNG print size is not reliably embedded. These are not claims of print quality or printer support.
- The image optimizer flattens alpha onto white before resizing, accepts bounded internal working copies up to 16 MiB, and wraps a JPEG on A4 with margins instead of mapping pixels directly to PDF points. PDF and HTML are not encrypted. Added source tests; real codec/Flutter/device tests remain unrun.
- Actual Dart budget and sheet geometry checks passed for 56 media entries under DartPad DDC/Node; several UI/control-flow checks used stubs. See [validation](docs/engineering/VALIDATION.md) for scope and remaining release gates.

## Unreleased — scan enhancement and OCR handoff (not a release)

- Added reviewable Original, Lighten, Reduce shadows, Magic Pro, Grayscale and adaptive B&W document modes, with three reproducible fictional practice pages and actual [pixel-engine comparison evidence](docs/engineering/magic-scan-evidence.png). These classical algorithms can lose detail or leave shadows; they are not a claim of CamScanner parity.
- Added optional, reviewable bright-page corner suggestions with manual fallback, and a direct selected-scan-page handoff to the offline OCR screen. Scan multipage PDFs remain image-only; OCR searchable PDF handles one image and uses the original recognized words, with a warning after text edits. Corrected TXT/DOCX remain available.
- Bounded internal scan PNGs up to 16 MiB can be prepared for OCR; external image picks remain at 8 MiB. Failed preparation no longer leaves the old image available under a new label. Added tests, but this branch has not run through Flutter or Android.
- Integrated the later main snapshot's source-referenced photo-sheet profiles, corrected a Dart constant-expression error and clarified profile/upload and unaltered-photo limits. Updated template slot-label assertions for the new heading; these Flutter tests remain unrun.
- Pixel smoke/sample tests passed under DartPad DDC/Node. Separately run CI passed for main `b226257`, not this feature branch; an earlier `1cef153` run failed analysis and full logs were unavailable. This branch still needs the complete Flutter run. No device or signed-release result is claimed for the new code. See [validation](docs/engineering/VALIDATION.md).

## Unreleased — document and photo cleanup (not a release)

- Added local, adjustable uneven-lighting and adaptive black-and-white cleanup for document images, with temporary before/after previews, cancel/apply, existing draft undo/reset, and PNG or image-PDF export. Transparency is flattened to white; color, artwork or light text can be altered.
- Added a bounded 3 × 3 selective isolated-speck filter for photos up to 4 megapixels, zoom and original comparison. Borders and transparent neighborhoods are left alone; fine details may soften and this is not general restoration.
- Added a deliberately shadowed field-notes page and a noisy synthetic garden photo, in-app practice instructions, before/after evidence, and cleanup unit/widget tests. The actual Dart pixel cores passed DDC/Node smoke and sample checks; **the new Flutter tests, real codecs/UI, Android and full suite remain unverified**. See [validation](docs/engineering/VALIDATION.md).

## Unreleased — document workflows (not a release)

- Added manual four-corner projective correction with optional A4/Letter proportions, rotate and grayscale/fixed-threshold enhancement; ordered A4/Letter image-only PDFs and bounded local draft recovery. Android camera uses `image_picker` and an injectable lost-capture boundary; native execution remains unverified.
- Added exact-pixel Photo resizing, compare/undo/reset and review of actual encoded dimensions/bytes; added an explicit supported/unavailable conversion catalogue.
- Added skippable welcome, revisitable tutorials, fictional page/design samples and a synthetic practice photo; tutorials call the real processors. Added D+S master logo, Android adaptive/legacy/monochrome resources and splash; Android resource build/rendering remains unverified.
- Added scan, draft failure/reopen, camera-fake, sample, responsive layout and navigation tests; user guide, conversion registry, engine evaluation and Pub dependency notice inventory.

At that earlier stage, the host baseline had 44 tests, later targeted scan (7), Photo widgets (4), sample assets (2), scan processor (5), and conversion/navigation (3) passed; a two-page image PDF was independently parsed and pixel/order checked. Later validation is recorded separately in [validation](docs/engineering/VALIDATION.md).

At the time of this older slice, OCR, searchable PDFs and office conversions were unavailable; they have since been added with limits described above. Existing-PDF reader/editing and cloud sync remain unavailable. This work is not release-ready.

## Earlier unreleased integrated foundation

- Restored the earlier Photo, Notes, Print, Business and editor modules within current main's physically dimensioned Creative Studio workspace, without deleting earlier project files or replacing main's workflow.
- Added editable text/shapes/images, manipulation, history, local save/reopen and safe copy import/export; added bounded one-way `.dsproject` conversion and same-installation discovery.
- Added bounded local photo operations, repeated-photo sheet preview/PDF/print handoff, accurate PDF page geometry and injectable print adapter.
- Hardened local writes, failure/retry/unsaved-exit behavior, catalogue stock counting and exact minor-unit calculations; added catalogue and notes exports.
- Preserved current main's checked-in Android scaffold and package ID; debug builds are explicitly for testing and release signing requires a local private configuration. Corrected the build script's repository-root detection.
- Added host tests, offline/privacy/format/printing documentation, attribution and an inactive CI proposal.

Validation in this execution: Flutter 3.47.8 / Dart 3.13.7; formatter and analyzer passed and 44 integrated host tests passed sequentially. System-print tests use fakes. No integrated Android/desktop packaging, actual printer or device testing was performed. The earlier creative-branch debug APK is not this integration.
