# DeskSuite brand assets and Android identity

## Canonical source

- `assets/brand/desksuite-mark.svg` is the transparent master vector mark. Keep the open-page crease and interlocking D/S geometry intact.
- `assets/brand/desksuite-app-icon.svg` is the desktop/AppImage icon variant with the same mark over the warm ink background.
- `lib/app/theme.dart` draws the mark natively in the Flutter interface so the app does not need a runtime SVG renderer.
- Android vector resources under `android/app/src/main/res/drawable/` provide adaptive foreground and monochrome icon artwork. Adaptive icon XML supplies the background separately; do not bake a second background into the foreground vector.
- Legacy density icons, adaptive/monochrome resources and splash XML are already part of the Android project. Their actual appearance still needs physical-device checks.

## Palette and usage

- Ink: `#292824`
- Paper: `#FBF8F1`
- Terracotta: `#ED9A7A`
- Keep surfaces warm and professional. Avoid unrelated blue gradients, emoji as brand marks, or rasterized text at launcher scale.
- The transparent SVG is the source of truth. The launcher uses the application label “DeskSuite”; do not add a small wordmark to the icon.

## Validation and release gate

The brand SVGs are bundled as assets and validated for their viewBox and canonical palette. Android resource compilation must pass in CI. A physical launcher/splash appearance check is still required on an Android 8+ device and a themed-icon check on Android 13+ before release.
