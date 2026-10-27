# Brand asset sources and regeneration

The custom D+S mark is in `assets/brand/desksuite-mark.svg`; the transparent 1024×1024 PNG is `assets/brand/desksuite-mark.png`. `lib/app/theme.dart` draws a matching in-app mark. The Android manifest points to `@mipmap/ic_launcher`; its resources include legacy density PNGs, adaptive foreground/background (v26) and monochrome (v33), with launch backgrounds and v31 splash themes under `android/app/src/main/res/`.

To regenerate on a development machine with Python 3, Pillow and ImageMagick 7 available:

```sh
python3 tools/generate_brand_assets.py
```

Review the master, regenerated PNGs and XML diff before committing. The script rasterizes the SVG using ImageMagick; different renderer/font configurations can affect output. The resources and manifest were structurally parsed and a legacy icon was visually inspected on the host, but **Android resource compilation, launcher masks, monochrome theming, splash behavior and actual small-size appearance have not been device-tested**. Verify them on representative Android versions and launchers before release.

`tools/generate_practice_documents.py` separately regenerates fictional page/design samples using Python, Pillow, NumPy and locally available DejaVu Sans fonts. It does not regenerate the separately supplied synthetic `practice-photo.jpg`.
