# DeskSuite engineering baseline

Audit recorded 2026-10-27, before the document-workflow changes on `agent/document-workflows`.

## Repository and verification provenance

- Repository: `https://github.com/ZamCan/DeskSuite`. Remote `main` was `b2d22cb0691eab3d3e39ccdb6cb14156f0b34f4f` when fetched. It incorporates the modular creative work but not the restored earlier studios.
- The starting tree for this work is `20d99a011bc99ef1d45e05d008e92dc7fdc98a7c`, a local, previously verified integration based on that main commit. It was recovered from a Git bundle, not fetched from a remote branch. No existing working files or remote branches were removed. See [integration history](../INTEGRATION.md).
- The integration previously passed formatting (46 Dart files), static analysis and 44 sequential host tests with Flutter 3.47.8/Dart 3.13.7. Those are results from the previous execution, not evidence that a later change, target build or device run passed. The original host test log is outside the repository; current verification is recorded separately with the changes.
- Android, native picker, physical printer and desktop execution were not tested for the integrated tree. An earlier debug APK is not an artifact of this integration. This checkout does not include a previously configured Android SDK or release key.

## Platform and application

Flutter/Dart; `pubspec.yaml` declares Flutter >=3.47 and Dart >=3.13. Locked direct application packages: `file_picker` 13.1.0, `path_provider` 2.1.6, `image` 4.12.0, `pdf` 3.13.1 and `printing` 5.15.1. Device-dependent versions of minSdk, targetSdk and compileSdk come from the selected Flutter SDK rather than fixed numbers in the application Gradle file; verify them from a locally built manifest. The earlier, different debug APK was API 24+, but is not proof of the integrated release's manifest. Gradle wrapper 9.3.1 is checksum-pinned; Android Gradle plugin is 9.1.0 and Kotlin plugin is 2.4.0. Java source/target is 17; use a Gradle-compatible JDK, commonly JDK 21.

Android label is `DeskSuite` and application ID/namespace are `com.zamcan.desksuite`. The manifest references legacy PNG launcher resources; the launch background is a plain colour and there is no checked-in adaptive icon. `lib/app/theme.dart` supplies the shared Material theme. `WorkspaceScreen` uses a drawer on narrow layouts and sidebar on wider ones; restored studios currently have light surfaces even in dark mode. There is no system-wide localization framework, first-run onboarding or sample library. The home page lists local projects and includes decorative, non-interactive artwork; see [integration notes](../INTEGRATION.md).

## Evidence-based capability matrix

"Host-tested" below means the named tests passed in the **previous integration run**, not that native/device behavior was verified. File paths identify real implementation rather than a visual control alone.

| Capability | Baseline evidence, dependencies and host tests | State / required action |
| --- | --- | --- |
| Camera capture | No camera module, plugin or capture entry point. | Absent. Choose an actual supported capture mechanism; validate on devices and handle cancellation/lifecycle. |
| Document scanning | Photo pipeline in `lib/images/photo_processor.dart`; `test/photo_processor_test.dart` exercises rotate, flip and centred square crop. | Partial image preparation only. No page detection, corner/perspective correction or multipage scan UI. |
| OCR/searchable PDF | No recognizer, OCR model, text layer or OCR tests. | Absent; distinguish text recognition from PDF creation and evaluate engine, model availability and licensing. |
| PDF reading/organization | `lib/printing/design_export.dart`, `photo_sheet.dart`, and `legacy_studios.dart` generate PDFs with `pdf`; `test/export_test.dart`, `photo_sheet_test.dart` and print-gateway tests cover generation. | Partial PDF **creation** only; no PDF import, reader, page manipulation, password handling or annotations. PDF content is raster/placed image, not searchable. |
| Image processing | `lib/images/photo_processor.dart`, `PhotoPage` in `lib/legacy_studios.dart`; `image` and `file_picker`; `photo_processor_test.dart`, `photo_widget_test.dart`. | Host-tested import, inspect, rotate, flip, square crop, fit/stretch resize, PNG/JPEG export and repeated-photo PDF. Native file access unverified; input/decoded-pixel/working-output limits apply. |
| Editable documents | `lib/design/`, `lib/workspace/creative_studio_page.dart`, `.dsdesign` repository; `design_engine_test.dart`, `creative_studio_flow_test.dart`, `workflow_integration_test.dart`. Notes are plain text. | Editable graphic-design pages and plain notes exist. Not a paginated word processor; no DOCX editor, tables or editable office templates. |
| Office support | No office document engine or office-format tests. | Absent. Do not equate raster canvas exports with editable DOCX/XLSX/PPTX. Evaluate local/remote engines and licences. |
| Conversion and compression | Photo PNG/JPEG outputs and single-page image PDFs as above. JPEG quality control is tested for valid output. | Partial, distributed by feature; no centralized route catalogue, PDF optimization, Office conversion or PDF-to-image path. |
| File workspace | `project_repository.dart`, `file_gateway.dart`; `project_repository_test.dart`, `file_gateway_test.dart`, `suite_navigation_test.dart`. | Local editable projects, import/export/delete with confirmation and native save/pick abstraction; not a general SAF file manager. No arbitrary folder move/copy or content-URI retention. |
| Tutorial/onboarding | No first-run state, tutorial assets or tutorial-processing tests. | Absent. Do not advertise a sample processing tutorial until it calls a real pipeline. |
| Launcher, splash, identity | `android/app/src/main/res/mipmap-*`, `drawable*/launch_background.xml`, manifest and `BrandMark` in `lib/app/theme.dart`. | Custom legacy PNGs and basic background exist; no adaptive-icon foreground/background set and no logo-regeneration source found. Visual quality and Android rendering unverified. |
| Cloud | No OAuth client, external account or transfer service. | Absent. Local use does not require a cloud account; no configured Google Drive flow. |
| Storage/integrity | `core/atomic_file_store.dart`, `local_file_store.dart`, `suite_paths.dart`, `project_repository.dart`; storage, migration and unsaved-change tests. | Host-tested bounded imports, atomic-replacement/backup recovery and separate roots for new and earlier data. Export copies individually; full backup/restore is absent. Different Android IDs and signing identities do not share private data automatically. |
| Print | `printing/print_gateway.dart`, `design_export.dart`, `photo_sheet.dart`; fake-gateway tests. | Real PDF bytes handed to an injectable system gateway; actual drivers, device dialog, page scaling and physical margins unverified. |
| Release and CI | `.github/workflows/build.yml`, `android/app/build.gradle.kts`, `tools/build-android.sh`, `docs/CI.md`. | Active CI attempts APK/AAB and desktop/iOS builds but supplies no release key; it has not been verified on this integration. Local Gradle supports externally supplied `android/key.properties`, not a configured CI signing flow. No signed integrated artifact or installation is verified. |
| Accessibility/responsiveness | Drawer/sidebar, scrollable controls, basic labels; widget tests at 360 logical pixels. | Partial. No systematic large-font, screen-reader, keyboard, orientation or real-device coverage. |

## Privacy and licences

The integration has no mandatory account, telemetry or model download. The main Android manifest does not explicitly declare camera or storage permissions; debug/profile manifests declare Internet for Flutter tooling, and merged-plugin manifests still require inspection during an Android build. Picker plugins may stage content before the app's Dart-side limits. App-private data is not encrypted by DeskSuite. Exported copies and printer services are controlled by platform/user choices; no blanket security or compliance claim is justified.

Direct SDK/package licence notices are in [THIRD_PARTY_NOTICES.md](../../THIRD_PARTY_NOTICES.md), with copies under `third_party/`: Flutter BSD-style, `file_picker` MIT, `path_provider` BSD-3-Clause, `image` MIT plus codec notices, `pdf`/`printing` Apache-2.0. `flutter_lints` is a development dependency. **This is not a complete transitive or native-binary audit.** No OCR model, office engine or third-party sample asset was present at baseline. Review all licences, native plugins, permissions and asset provenance before distribution.

## Release gate and staging

The first bounded priority is a complete, honest image/document-output workflow that reuses existing engines and keeps source files intact. Then extend capture/scan/OCR or PDF capabilities only with a real engine and validation. Keep `main` and the application ID unchanged. No feature or release gate becomes complete merely because code, a button or an artifact exists. See [roadmap](../ROADMAP.md), [development](../DEVELOPMENT.md), [privacy](../PRIVACY_AND_SECURITY.md), and [file formats](../FILE_FORMATS.md).
