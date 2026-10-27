# DeskSuite

**Create. Design. Print. Manage.**

DeskSuite is an offline-first creative workspace in early development. This repository currently contains an **Android-first Flutter application** and its first creative-workflow slice—not a finished office suite or point-of-sale product.

**Concurrent work:** while this increment was being developed, `main` gained a separate prototype with Photo, Notes, Print and Business tools. That work remains intact on `main`; it is not included in this branch and has not been integrated or validated with this editor. Do not merge this branch over it without reconciling both implementations. See [integration notes](docs/INTEGRATION.md). Earlier `.dsproject` files can be imported as editable copies, subject to the documented limits.

## What exists today

- Create an A4, A5, A3, business-card, square or custom-sized design, or start from a local editable poster template.
- Add editable text, rectangles, ellipses and locally selected PNG, JPEG or WebP images. Select and drag objects; resize, rotate, duplicate, align, reorder and delete them. Edit text, size, weight, alignment and a small colour palette. Zoom and fit the canvas.
- Undo/redo supported edits during the current editor session. Designs autosave to app-private storage and can be reopened. Export/import an editable `.dsdesign` project copy; import compatible earlier `.dsproject` copies.
- Export a PNG or single-page, physically sized, raster PDF at 150 or 300 dpi. A warning is shown when an image is lower resolution than the requested output.
- A local file picker, light/dark appearance, a recoverable local project store, and an offline-oriented design engine.

The design engine, storage, export and phone-sized widget flow have automated host tests. A successful host test is **not** an Android-device test. No printer, device, accessibility service or production release has been validated yet.

## Not yet implemented

Photo editing and passport sheets; office documents, spreadsheets and PDF merge/edit; direct printing, print queues and imposition; inventory, POS, accounting and database backups; advanced vector editing, font selection, crop, snapping and grouping. The corresponding navigation entries are labelled **Planned**. See [the roadmap](docs/ROADMAP.md) for capability status.

## Build and test

Requirements: Flutter **3.47.8**, Dart **3.13.7**, JDK 21, Android SDK platform 36 and build tools, plus accepted Android SDK licences. The generated Android app ID is `com.zamcan.desksuite`; minimum Android API is 24. An Android device/emulator is required to run or install it.

```sh
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test --reporter expanded
flutter build apk --debug
```

An ARM64 debug APK was built in the development environment with `flutter build apk --debug --target-platform=android-arm64 --split-per-abi`; the output is `build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk`. This development-signed file is not a production release. On a connected compatible Android device, install it with `adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk` or run with `flutter run`; those device operations remain unverified. The temporary debug signing key is not a production identity, and a separately generated key cannot update the app without migration or removal of the prior installation.

See [development](docs/DEVELOPMENT.md), [architecture](docs/ARCHITECTURE.md), [file formats](docs/FILE_FORMATS.md), [printing](docs/PRINTING.md), and [privacy and security](docs/PRIVACY_AND_SECURITY.md).

## Data ownership and limits

Projects are stored locally in the app's private files, unencrypted by DeskSuite. Android can delete those files on uninstall or clear-data; export editable project copies first. Autosave is debounced, so a sudden process termination can lose very recent changes. Images are embedded in project files; originals are not overwritten. Project files are limited to 32 MB, individual imported images to 8 MB and 20 megapixels, unique decoded images to 24 megapixels combined, and rendered output to 16 megapixels and 8192 pixels per side.

## Licence

The repository is [Apache-2.0](LICENSE). Direct dependency notices are in [third_party](third_party/) and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md); `pubspec.lock` records exact resolved versions.
