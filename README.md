# DeskSuite

**Create. Design. Print. Manage.**

DeskSuite is an offline-first, Android-first creative workspace intended to grow into a combined design, photo, office, print and stationery-business suite.

## Current engineering baseline

The active app entry point is the modular creative editor from the reconciled creative-studio branch. The older single-file prototype from the previous `main` branch is preserved at [docs/archive/main-prototype.dart.txt](docs/archive/main-prototype.dart.txt) as a migration reference; it is not a second active application entry point.

### Active and automated-tested design slice

- Create physical-size layouts such as A4, A5, A3, business cards, square and custom dimensions.
- Add and edit text, rectangles, ellipses and local PNG/JPEG/WebP images.
- Select, drag, resize, rotate, duplicate, align, reorder and delete design layers.
- Undo/redo within the current editor session.
- Save and reopen versioned local design projects; import/export editable project copies.
- Export bounded PNG and single-page raster PDF output at selected DPI, with source-image resolution warnings.
- Local-only project storage and platform file-picker boundary, with automated host tests for document, repository, export and widget flows.

### Preserved prototype capabilities to migrate into modular screens

The earlier prototype included basic Photo tools, Notes, an A4 print-test sheet, a local product catalogue and stock decrement. Its source is preserved in the archive above. Those tools are **not yet integrated into the active modular navigation** and must be migrated with tests before being described as complete.

### Not yet implemented as production features

- Canva-level templates, advanced vector tools, background removal and full photo editing.
- Full DOCX/XLSX editing and spreadsheet formulas.
- Passport-photo sheets, production print queues, imposition and printer-specific calibration.
- Complete inventory/POS, receipts, accounting, expenses, payments and reporting.
- Desktop release validation and signed iOS/App Store packaging.

## Repository structure

- `lib/design/`: document model, geometry, editor controller, renderer and editor UI.
- `lib/workspace/`: workspace/navigation, local project repository, file gateway and project creation.
- `lib/printing/`: bounded design-to-PNG/PDF export logic.
- `android/`: checked-in Android Gradle runner.
- `test/`: automated Flutter tests.
- `tools/build-android.sh`: local Android build, analysis and test sequence.
- `.github/workflows/build.yml`: GitHub Actions validation/build matrix.

## Build requirements

This is a Flutter/Dart project with an Android Gradle runner. **Gradle alone is not enough**: the Flutter SDK is required to compile Dart code and generate Flutter plugin registrants.

Requirements for a local Android build: compatible Flutter stable SDK, Dart bundled with Flutter, JDK 21, Android SDK/platform tools and accepted SDK licences. The checked-in Android project uses package ID `com.zamcan.desksuite`.

```bash
git clone https://github.com/ZamCan/DeskSuite.git
cd DeskSuite
bash tools/build-android.sh
```

The script runs dependency resolution, formatting, static analysis, tests and a release APK build. Expected output:

`build/app/outputs/flutter-apk/app-release.apk`

If Flutter is not installed, the script stops safely and points to [GitHub Actions](https://github.com/ZamCan/DeskSuite/actions) for a remote build. Download the Android artifact only after the relevant workflow completes successfully.

## Cross-platform packaging

Flutter can share application code across Android, Windows, Linux and iOS, but each target still needs its own toolchain and validation. Windows builds require Windows/Visual Studio C++ tools; Linux builds require desktop development libraries; iOS builds require macOS/Xcode. An unsigned iOS build is validation only, not a store-ready IPA.

CI-generated APKs without a configured persistent production signing key are validation builds, not a stable production upgrade channel. Do not publish them to Google Play or expect separate CI builds to update each other until signing is deliberately configured and verified.

## Offline and data safety

The core design editor and local project storage do not require a network service. Project files are stored in app-private storage; uninstalling the app or clearing its data may remove them. Export editable project copies for backup. Physical printer availability and platform file dialogs depend on the operating system.

See [architecture](docs/ARCHITECTURE.md), [development](docs/DEVELOPMENT.md), [roadmap](docs/ROADMAP.md), [file formats](docs/FILE_FORMATS.md), [printing](docs/PRINTING.md), and [privacy/security](docs/PRIVACY_AND_SECURITY.md).

## Licence

Apache License 2.0. See [LICENSE](LICENSE).
