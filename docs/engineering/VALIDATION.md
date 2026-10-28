# Validation record

## Scan enhancement, suggestions and OCR handoff — 2026-10-28

The repository's independently running [CI run 40634495478](https://github.com/ZamCan/DeskSuite/actions/runs/40634495478) completed successfully for **baseline commit `4c155232a09b20a290210c697a719ea8bb65a8f0`**, before these changes: its Flutter analysis/tests and Android, Linux, Windows and unsigned-iOS build steps succeeded. Later [run 40635793861](https://github.com/ZamCan/DeskSuite/actions/runs/40635793861) failed at Flutter analysis for main `1cef153ee782e4ed4feb859c3f34d313dc466d32`; authenticated logs were not accessible. Separately, DartPad analysis of its actual `photo_specifications.dart` reproduced `const_eval_property_access` for a `const` initialized from a list's `.length`. This feature branch changes that derived index to `final` and removes the corresponding `const` menu item; direct analysis of the modified registry reports no issues. That is not a complete project analyzer run, and it is not proven to be the only CI failure. Two source test predicates were also narrowed to exact slot labels after a main-branch heading started containing the same dimensions; those Flutter tests are unrun.

A DDC/Node smoke check of the actual updated registry passed index, unique IDs, dimension/source invariants and the profile-scope warnings. Separately, the actual template generator composed with element/ID stubs produced 20 exact slot labels plus one heading containing the same dimensions, confirming why the two test predicates needed narrower matching. The composed smoke sources had only unused harness-import warnings. The actual photo-sheet dialog plus registry also analyzed without issues when composed with local type/signature stubs. These checks do not exercise real PDF generation, widgets, plugins or printing.

Neither run is a test of this feature branch, a device install, or a verified signed release. We did not start these runs or download an Android toolchain/build packages in this workspace.

For the **new code**, the actual dependency-free Dart pixel cores and standalone smoke scripts were analyzed and compiled with DartPad **Dart 3.13.7 DDC**, then executed locally under Node. Both passed: document modes including Original/Lighten/Magic Pro/gray/adaptive B&W, alpha/invalid input and 40 randomized images; plus synthetic perspective page suggestions, immutable inputs, blank/dark/edge-cut fallbacks and invalid dimensions. This is JavaScript/DDC evidence, not Dart VM, Flutter widget/codec, native-isolate or Android evidence.

The actual Dart cleanup core processed the fictional `shadowed-practice-page.png` via local raw RGBA files. At (30, 500), paper RGB (134, 131, 123) became (176, 172, 162) with Lighten 0.7, (212, 207, 195) with shadow reduction 0.7, (250, 244, 229) with Magic Pro 0.9 and white with adaptive B&W 0.7. A green chart pixel stayed green in Magic Pro; it became black in B&W. This is a synthetic example, not an accuracy or shadow-removal guarantee. [Five-mode comparison](magic-scan-evidence.png) was composed from those actual Dart outputs and is **not an Android screenshot**.

The same corner core was run on Pillow-downsampled synthetic assets locally. On the 1500 × 1900 angled practice scene, its normalized points were approximately (0.169, 0.102), (0.841, 0.063), (0.883, 0.908), (0.127, 0.932); the generator's intended corners are approximately (0.167, 0.103), (0.841, 0.063), (0.882, 0.908), (0.125, 0.932). The earlier perspective-letter fixture also produced close points; a full-frame shadowed page and the garden image returned no suggestion. These few artificial cases do **not** establish real-camera recall, false-positive rate or device performance. User images were not uploaded to the compiler.

All changed Dart files were formatted using DartPad's 3.13.7 formatter. Analyzer checks on the actual cleanup dialog, corner editor, scan screen and OCR screen composed with local-interface stubs reported no code errors; the OCR composition had one redundant stub-import info. The actual corner core/wrapper also analyzed against codec stubs with no issues. Stubs do not validate the project's real `image` codec, file storage, widgets, isolates or platform channels. The three practice images regenerated to identical SHA-256 hashes and Pillow verified their formats and dimensions.

Added Flutter tests cover the modes, generated sample, review/cancel/manual corner fallback, selected-page OCR handoff, bounded 8–16 MiB scan preparation, previous-source clearing on failed preparation, and explicit confirmation when reviewed text differs from the searchable-PDF OCR layer. They are **written but have not run** in Flutter here. Run the commands below on the owner's existing toolchain; independently test Android camera/OCR, low memory, providers, printing, signing, installation and real page quality.

## Cleanup slice checks on 2026-10-27

The previously installed host Flutter/Dart tools were not present in this workspace snapshot. No Android tools were downloaded. To obtain real evidence without packaging, the **actual, dependency-free Dart pixel source** and checked-in `test/pixel_algorithms_smoke.dart` were analyzed and compiled with DartPad's Dart **3.13.7** DDC, then executed as JavaScript under Node. The standalone check passed, including uneven lighting, adaptive B&W, dark ink, alpha flattening, invalid settings, selective speck removal, transparent-neighborhood protection and 40 deterministic randomized images. This is a DDC/JavaScript run, **not a Dart VM, Flutter integration or Android-device test**.

A separate Node/DDC boundary smoke run processed a uniform **12-megapixel** RGBA document (17.835 s) and a **4-megapixel** RGBA photo (9.837 s), with the expected output checks passing; peak child RSS for the combined Node run was approximately 303 MB. These figures include the DDC/Node environment and both synthetic buffers and must not be used as Android performance or memory estimates.

The same actual pixel functions processed the bundled synthetic examples using local raw RGBA input. On `shadowed-field-notes.png`, one shaded paper pixel (30, 400) changed from RGB (131, 131, 129) to (203, 203, 200) with lighting strength 0.7; adaptive B&W produced white there and black at a selected chart pixel. On the 1376 × 768 noisy garden, 53,022 RGB pixels changed; whole-image mean absolute channel error versus the synthetic clean base decreased from **10.177 to 3.585**. This is one artificial impulse-noise example, not a quality guarantee for real photographs. See [visible before/after evidence](cleanup-evidence.png); Pillow composed the evidence from the local engine outputs. No user images were uploaded to the compiler.

DartPad's Flutter **3.47.8** analyzer reported no issues when the new scan dialog and scanner UI were composed with local-interface stubs, and separately for the Photo Studio UI, photo processor and document cleanup wrapper with codec/interface stubs. The new/modified Dart files were formatted using the same service's Dart 3.13.7 formatter. These checks can catch syntax and many Flutter API mistakes, but the stubs do **not** verify the real `image` codec, plugin bindings, isolates, storage, navigation, layout, or the complete project. The new `document_cleanup_test.dart`, `document_cleanup_dialog_test.dart`, `image_cleanup_test.dart`, sample and widget integration tests are **written but have not run** under Flutter. Run them and the complete suite on the owner's existing toolchain; do not infer a release or device pass.

## OCR and office work: real runs on 2026-10-27

Environment: Flutter 3.47.8 / Dart 3.13.7 on a Linux host. These are host test
results, **not** Android, camera, device-memory or recognition-quality evidence.

- First execution of the document-workflow suite exposed **5 failures**: four in
  `photo_widget_test.dart` and one in `navigation_test.dart`. Every one was the
  same harness defect — `WidgetController.ensureVisible` was called on a key
  inside a lazy `ListView` that had not built that child yet. Added
  `test/support/reveal.dart` and routed the call sites through it. The
  assertions themselves were unchanged. Suite then passed 87.
- The OCR work added `lib/ocr/` and a native `OcrChannel`. `flutter test` now
  reports **152 passed**. New tests: `ocr_engine_test` (8), `ocr_exports_test`
  (9), `searchable_pdf_test` (7), `ocr_image_prep_test` (4), `ocr_page_test`
  (5), `office_engine_test` (28), `office_convert_page_test` (4).
- `searchable_pdf_test` inflates the generated PDF's Flate content streams and
  asserts that every recognized word appears in the page content, that exactly
  one page and one embedded image XObject exist, and that page order is kept.
- `office_engine_test` builds genuine DOCX/XLSX/PPTX/ODT/ODS packages in memory,
  asserts their content is read correctly, round-trips written ODT/ODS back
  through the reader, verifies generated PDFs begin with `%PDF-` and contain page
  objects, and checks the package limits with a 4100-part archive.
- `dart test/pixel_algorithms_smoke.dart` still passes (40 randomized images).
- `flutter analyze` reports no issues; `dart format --set-exit-if-changed` is
  clean.

Bug fixes found by these runs, not by inspection:

- `pw.Positioned` in the `pdf` package takes no `width`/`height`.
- Every generated DOCX carried a spurious empty final paragraph.
- ZIP-based office detection could not work from a byte scan, because archive
  entries are compressed; the container must be opened and its parts inspected.
- The built-in PDF font (Helvetica) silently dropped em dashes and other
  non-WinAnsi glyphs; PDFs now embed a Noto Sans subset.
- The RTF reader skipped the entire document because its skip pattern matched an
  inner `{\fonttbl` group from the outer brace.
- `TessBaseAPI` has no `end()`; the Android job failed to compile until the call
  was changed to `recycle()`.

Not verified by any of this: recognition accuracy, native camera or Tesseract
behaviour, memory use on a real phone, LibreOffice invocation, or any Android
build/install. No APK was produced in this environment.

## Earlier host checks performed on 2026-10-27

Environment for the recorded runs: Flutter 3.47.8 / Dart 3.13.7 on a Linux host; sequential tests (`--concurrency=1`). These are host tests, **not** Android installation, native plugin, printer, or release verification.

- Before document-workflow changes, format and `flutter analyze --no-pub` passed; **44 baseline host tests** passed on the saved integrated tree `20d99a0`.
- After scan, photo, onboarding, sample and conversion implementation, `flutter analyze --no-pub` passed. A subsequent edit adjusted a widget-test assertion; a fresh analyzer run of the final tree is still required.
- `test/scan_studio_widget_test.dart`: **7 passed**, including real page correction/export, two-page tutorial, reordering and reopen, simulated storage failure with camera-byte recovery/retry, compact 320×568 at 1.5× text, landscape 568×320 at 1.8× text, and injected camera/recovery entry points. These use fake native gateways, not an Android camera.
- `test/photo_widget_test.dart`: **4 passed**, including real PNG/JPEG processing, exact-dimension output and sample tutorial. `test/scan_processor_test.dart`: **5 passed**; `test/sample_assets_test.dart`: **2 passed**. Additional scanner draft, camera-gateway, PDF, photo-processor, onboarding and navigation targeted tests passed in earlier runs.
- `test/conversion_catalog_test.dart` and `test/suite_navigation_test.dart`: **3 passed** after fixing a test that had assumed off-screen lazy-list children were built. Catalogue buttons were exercised, including navigation to the real Photo Studio; unsupported entries have no action.
- A two-page PDF produced by `createScanPdf` from the bundled report images in reversed order was inspected separately with Python `pypdf 6.7.4` (`strict=True`) and Pillow. The 102,920-byte file had two pages, both with A4 media boxes of 595.27559 × 841.88976 pt, exactly one embedded image each, and images pixel-identical to `report-2.png` then `report-1.png` (1000 × 1414 each). Independent text extraction returned an empty string on both pages, as expected for an image-only PDF. This did not test a mobile PDF reader or printed output.
- Android XML assets were parsed and a legacy launcher PNG was visually inspected. This does **not** prove Android resource compilation, adaptive icon/splash rendering or device behavior.

The **complete suite has not been rerun after all feature additions**. Prior targeted success is not a full-suite pass. In the later workspace session the host Flutter cache was no longer present, and no Android SDK, `adb`, `apksigner`, emulator, release key, or JDK 21 was available. In accordance with the owner's instruction, Android toolchains and packaging were not downloaded. No current APK/AAB was built, signed, installed or launched.

## Re-run on the owner's existing toolchain

```sh
flutter pub get
dart test/pixel_algorithms_smoke.dart
dart test/page_corner_pixels_smoke.dart
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub --concurrency=1 --reporter expanded --timeout 120s
# Then follow the Android build, signing, signature-verification and device
# checklist in docs/DEVELOPMENT.md using already-installed tools and your key.
```

Test at least camera cancellation and interrupted-activity recovery, content providers, save cancellation, corrupt/large images, disk-full behavior, upgrades from the same application ID/signing key, compact/landscape/large-text layouts, offline use, launch icon/splash, and a real PDF viewer. Test results must be recorded from the actual device and build; do not infer them from the host tests.


## 2026-10-28 source changes — not yet run through Flutter

Added a photo background-compositing path to the existing bounded photo processor and a Photo Studio action for placing already-transparent content on a selected solid colour. Added unit and widget tests for compositing, invalid translucent colour values, and the Photo Studio import → choose background → export workflow. The Photo Sheet preset UI was also added in the previous slice.

These source changes have **not** been run through Dart formatting, Flutter analysis, the full Flutter test suite or an Android build in this execution. Do not interpret the added tests as passing tests. Run the command sequence above on the maintained toolchain and record the actual result before claiming verification.

## 2026-10-28 — editable template registry tests added

Added `test/design_template_catalog_test.dart` for unique stable IDs/labels, element bounds, and serialization round-trip; added `test/new_design_dialog_template_test.dart` for selecting a business-card template in the UI and creating an editable project.

These tests are **written but not executed in this session**. No formatter, analyzer, full-suite or Android build result is claimed for this change. Run the commands above and record their actual output before treating the tests as passing.

The catalogue now includes source/licence/schema metadata and guards template generation against unsupported canvas dimensions. Tests were expanded for 10 mm and 1200 mm edge cases and invalid dimensions. They remain unexecuted until the current GitHub Actions run completes.

### Narrow-screen photo background picker

The workflow run [40631293017](https://github.com/ZamCan/DeskSuite/actions/runs/40631293017) reported 178 passing tests and one failure: a 3.5 px horizontal RenderFlex overflow while exercising the solid-background photo picker on a 360 px test viewport. The template catalogue and template-dialog tests passed in that run. The background-option labels were constrained to a flexible, ellipsized line in commit 76e0cc6742b4ca28c196fb139bf9c57138864f56. Await the next full CI run to verify the correction.



## 2026-10-28 — photo print-sheet template source tests

Added a shared A4 photo print-sheet starter with twenty editable example slots and a test for the rectangle/text counts. The slots are not image frames and no official size or printer scaling is certified. The test is **not yet confirmed passing**; wait for the latest GitHub Actions run. No Android build/device result is implied.


## CI follow-up — asynchronous widget-test waits (2026-10-28)

A later Android matrix test run completed formatting and analysis, then reported 176 passing tests and three widget-test failures: the workspace-navigation test attempted to scroll before the Creative Studio list existed; the scan retry assertion checked the recovery error before the async save transition had cleared; and the unsaved-changes test tapped the editor action before it was present. The tests now wait on the actual widget/state transition instead of fixed pump counts. This is a test-harness stabilization change, not proof that the next run passes; re-run the full matrix and inspect any persistent failures as possible application defects.


## Photo print-sheet image placement — pending validation (2026-10-28)

Added a controller test for filling a template photo slot with a locally selected PNG, preserving the image through project encode/decode, undoing the replacement and refusing to replace an ordinary rectangle. The shared renderer now uses cover fitting for image layers. These tests have not yet been confirmed by the current GitHub Actions run; do not report them as passing until the new run completes. Android/device image picker, memory, crop and printer output remain separate validation gates.


## CI follow-up — photo-slot regression (2026-10-28)

The current Android run found the photo-sheet catalogue test's text count was one low: the generated sheet has 23 text elements (header, subtitle, twenty labels and footer). Corrected the assertion and added a controller-level test for image replacement, label removal, project encode/decode, and undo. These changes await CI confirmation.
