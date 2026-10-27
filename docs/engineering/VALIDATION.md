# Validation record

## Cleanup slice checks on 2026-10-27

The previously installed host Flutter/Dart tools were not present in this workspace snapshot. No Android tools were downloaded. To obtain real evidence without packaging, the **actual, dependency-free Dart pixel source** and checked-in `test/pixel_algorithms_smoke.dart` were analyzed and compiled with DartPad's Dart **3.13.7** DDC, then executed as JavaScript under Node. The standalone check passed, including uneven lighting, adaptive B&W, dark ink, alpha flattening, invalid settings, selective speck removal, transparent-neighborhood protection and 40 deterministic randomized images. This is a DDC/JavaScript run, **not a Dart VM, Flutter integration or Android-device test**.

The same actual pixel functions processed the bundled synthetic examples using local raw RGBA input. On `shadowed-field-notes.png`, one shaded paper pixel (30, 400) changed from RGB (131, 131, 129) to (203, 203, 200) with lighting strength 0.7; adaptive B&W produced white there and black at a selected chart pixel. On the 1376 × 768 noisy garden, 53,022 RGB pixels changed; whole-image mean absolute channel error versus the synthetic clean base decreased from **10.177 to 3.585**. This is one artificial impulse-noise example, not a quality guarantee for real photographs. See [visible before/after evidence](cleanup-evidence.png); Pillow composed the evidence from the local engine outputs. No user images were uploaded to the compiler.

DartPad's Flutter **3.47.8** analyzer reported no issues when the new scan dialog and scanner UI were composed with local-interface stubs, and separately for the Photo Studio UI, photo processor and document cleanup wrapper with codec/interface stubs. The new/modified Dart files were formatted using the same service's Dart 3.13.7 formatter. These checks can catch syntax and many Flutter API mistakes, but the stubs do **not** verify the real `image` codec, plugin bindings, isolates, storage, navigation, layout, or the complete project. The new `document_cleanup_test.dart`, `document_cleanup_dialog_test.dart`, `image_cleanup_test.dart`, sample and widget integration tests are **written but have not run** under Flutter. Run them and the complete suite on the owner's existing toolchain; do not infer a release or device pass.

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
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub --concurrency=1 --reporter expanded --timeout 120s
# Then follow the Android build, signing, signature-verification and device
# checklist in docs/DEVELOPMENT.md using already-installed tools and your key.
```

Test at least camera cancellation and interrupted-activity recovery, content providers, save cancellation, corrupt/large images, disk-full behavior, upgrades from the same application ID/signing key, compact/landscape/large-text layouts, offline use, launch icon/splash, and a real PDF viewer. Test results must be recorded from the actual device and build; do not infer them from the host tests.
