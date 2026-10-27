# DeskSuite brand assets and Android identity

## Canonical source

- `assets/brand/desksuite-mark.svg` is the master vector mark. Keep the open-page crease and interlocking D/S geometry intact.
- `assets/brand/desksuite-mark.png` is the transparent raster export for previews and documents.
- `assets/brand/desksuite-app-icon.svg` is the desktop/AppImage icon variant with the same mark over the warm ink background.
- `tools/generate-windows-icon.ps1` composes the transparent master mark on the same background and writes the Windows runner's ICO using a lossless PNG payload.
- `lib/app/theme.dart` draws the same mark natively with `BrandMark`; this avoids adding a runtime SVG renderer.
- `android/app/src/main/res/drawable/ic_launcher_foreground.xml` and `ic_launcher_monochrome.xml` are Android vector equivalents. The monochrome layer is for themed icons on Android 13+.
- `mipmap-anydpi-v26/ic_launcher.xml` defines the adaptive icon; legacy density PNGs remain for older launchers. `drawable/launch_background.xml` and the Android 12+ launch theme use the same warm ink background.

## Palette and usage

- Ink: `#292824`
- Paper: `#FBF8F1`
- Terracotta: `#ED9A7A`
- App surfaces use warm paper, walnut/ink and terracotta accents. Avoid introducing unrelated blue gradients or emoji as brand marks.
- The SVG is transparent by design. The Android adaptive icon supplies its background separately; do not bake a second background into the foreground vector.
- The launcher mark has no wordmark at icon scale. Use the application label “DeskSuite” for the name.

## Regeneration and validation

Run `python3 tools/generate_brand_assets.py` only in a development environment with Pillow and ImageMagick 7 installed. It regenerates Android vectors, density PNGs, splash XML and the transparent PNG from the SVG master. Review the generated diff before committing it.

The `tools/validate-brand-assets.py` script checks PNG headers/dimensions, SVG palette, Android density icons, adaptive/monochrome resources and splash references; Android and Linux CI run it. Windows CI generates its executable icon from the same transparent master mark before packaging. The `sample_assets_test.dart` suite checks that the canonical SVG and desktop icon are bundled and retain their identifying geometry and palette. Android CI validates resource compilation; a physical launcher/splash appearance check is still required on at least one Android 8+ device and one Android 13+ themed-icon device.