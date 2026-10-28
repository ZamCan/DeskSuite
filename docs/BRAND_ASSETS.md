# DeskSuite brand assets and platform identity

The owner-selected launcher identity is the blue dimensional **DS scan-frame** mark. `assets/brand/desksuite-icon-source.png` is the selected original; `assets/brand/desksuite-mark.png` is its processed in-app image. The earlier warm vector logo is not the selected launcher identity.

- `lib/app/theme.dart` displays the selected mark and shared blue palette. `lib/app/brand_launch.dart` draws a short startup treatment with the scan frame and then reveals that same image; system reduced-motion settings skip the animation.
- Android's density icons and adaptive foreground/background resources are generated from the selected image. The monochrome icon is a simplified themed-icon resource. Windows uses `windows/runner/resources/app_icon.ico`; the AppImage SVG embeds the exact in-app PNG. These are platform adaptations, not different logo selections.
- Six other selected design candidates were repurposed only as internal Scan, Photo, Text, Office, Creative Studio and Projects artwork. Their originals are in `assets/brand/section-sources/` and smaller UI copies in `assets/brand/sections/`.
- Regenerate with `python3 tools/generate_brand_assets.py` using Pillow; `python3 tools/validate-brand-assets.py` checks the selected source hash and resource references. `python3 tools/test_brand_assets.py` exercises regeneration. These are structural/host checks, not OS rendering tests.

Physical launcher masks, Android 13+ monochrome theming, native splash transitions, Windows/Linux appearance, accessibility and small-size readability must still be checked on target devices. Do not replace the selected app icon with an internal section illustration.
