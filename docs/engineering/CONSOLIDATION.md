# DeskSuite consolidation and phone-build checklist

## What this branch combines

This branch starts from the repository's current `main` and adds the existing-PDF editor, current scan widget-test readiness fixes, and editable stamps/signature marks. It deliberately does not merge every divergent branch wholesale: the main branch already contains the more complete scanner, OCR, Office content tools, Photo Studio, print workflows, and inventory/POS, and replacing those with older versions would regress work.

## Build and test before installation

Use a clean clone so old generated files do not affect the result:

```sh
git clone https://github.com/ZamCan/DeskSuite.git
cd DeskSuite
git checkout integration/complete-product-android-ready
flutter --version
flutter pub get
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --release
```

If the Termux environment does not have a compatible Flutter SDK and Android SDK configured, do not try to substitute only Java/Gradle: DeskSuite is a Flutter application and needs Flutter's Android build toolchain. In that case, use the Android APK artifact from the pull request's successful GitHub Actions run.

## Install on the Android phone

When the APK has been built successfully, install it with ADB from the connected computer/Termux environment:

```sh
adb devices
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

If Android rejects the update because the signatures differ, do not uninstall immediately if you need the current app's private data. Preserve/export any important files, then decide whether to keep the existing install or install the new build as a fresh app. ADB install success is not proof that camera, file picker, PDF editor, OCR, printing or recovery all work correctly on the device.

## Device acceptance checks

1. Launch DeskSuite and navigate between Creative Studio, Scan & assemble, Text extraction, Document converter, PDF Studio, Print Studio and Business & POS.
2. Import a non-sensitive paper photo, correct its corners, save a draft, leave/reopen the scan studio and export an image-only PDF.
3. Run OCR separately and verify recognized words in the searchable PDF.
4. Open a copy of an existing, non-sensitive PDF in PDF Studio; annotate or edit it and export to a different filename. Reopen the export in another viewer.
5. In Creative Studio, add a stamp and a drawn signature, move each layer, save, close and reopen the design.
6. Record real limitations and failures before calling this release-ready.

## Known release gates

- No claim of full Word/Excel/PowerPoint layout fidelity or LibreOffice parity.
- Scanner automatic edge detection and native camera behavior require real-device verification.
- PDF support varies by source file and the editor engine; protected/complex PDFs require testing.
- Signature drawings are not cryptographic, identity-verified or legally certified signatures.
- Printer discovery, paper sizing, Android scoped-storage/provider behavior, release signing and upgrades still need device validation.
- Do not merge the draft pull request until its exact head commit passes CI and the phone checks have been completed.
