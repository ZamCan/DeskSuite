# Brand asset sources and regeneration

The custom D+S mark is in `assets/brand/desksuite-mark.svg`, with a desktop/AppImage variant in `assets/brand/desksuite-app-icon.svg`. `lib/app/theme.dart` draws a matching in-app mark. The Android manifest points to `@mipmap/ic_launcher`; its resources include legacy density PNGs, adaptive foreground/background (v26) and monochrome (v33), with launch backgrounds and v31 splash themes under `android/app/src/main/res/`.

The current branch uses the SVG master and the existing Android vector/density resources; no generated transparent PNG master is bundled as a Flutter asset. The resources and manifest must pass structural validation and Android resource compilation, but **launcher masks, monochrome theming, splash behavior and actual small-size appearance have not been device-tested**. Verify them on representative Android versions and launchers before release.

`tools/generate_practice_documents.py` separately regenerates fictional page/design samples using Python, Pillow, NumPy and locally available DejaVu Sans fonts. It does not regenerate the separately supplied synthetic `practice-photo.jpg`.
