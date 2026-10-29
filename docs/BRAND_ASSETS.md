# DeskSuite brand assets and Android identity

## Canonical source

- `assets/brand/desksuite-reference-mark.png` is the supplied visual reference and the in-app `BrandMark` source of truth. Do not substitute a different monogram.
- `assets/brand/desksuite-mark.svg` is the scalable vector companion; `assets/brand/desksuite-app-icon.svg` is the desktop/AppImage variant.
- `lib/app/theme.dart` draws the mark natively in the Flutter interface so the app does not need a runtime SVG renderer.
- `lib/app/startup_view.dart` uses that same mark and palette while local storage initializes. It has no fixed delay, so it cannot hold the user on a splash once the workspace is ready.
- Android vector resources under `android/app/src/main/res/drawable/` provide adaptive foreground and monochrome icon artwork. Adaptive icon XML supplies the background separately; do not bake a second background into the foreground vector.
- Legacy density icons, adaptive/monochrome resources and splash XML are already part of the Android project. Their actual appearance still needs physical-device checks.

## Palette and usage

- Reference mark: white `#F8FBFF`, cyan `#26C6DA`, gold `#F3BD50`, framed blue `#153B66`.
- Keep the supplied mark and launcher colors consistent. The main product surfaces can remain paper/ink neutral; do not replace the mark with a different monogram, emoji, or unrelated gradient.
- The supplied reference PNG is the visual source of truth; the SVG and Android vector are scalable launcher companions. The launcher uses the application label “DeskSuite”; do not add tiny text to the icon.

## Validation and release gate

The brand SVGs are bundled as assets and validated for their viewBox and canonical palette. Android resource compilation must pass in CI. A physical launcher/splash appearance check is still required on an Android 8+ device and a themed-icon check on Android 13+ before release.
