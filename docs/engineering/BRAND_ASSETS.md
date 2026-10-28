# Brand asset sources and regeneration

The owner selected the dimensional blue DS, scan-frame, document/image and pen artwork on 2026-10-28. The **canonical source** is the original AI-generated raster `assets/brand/desksuite-icon-source.png` (1254 × 1254 RGB; SHA-256 `92e47c28fb5cadb71bd779153c831c5f65923d0e029b4c37a38cb08b68feece2`). It is preserved unchanged for regeneration and is not itself bundled into Flutter. Do not claim trademark clearance or exclusive ownership without a separate review.

The generated `assets/brand/desksuite-mark.png` is a 512 × 512 RGBA version used by the in-app sidebar, startup, welcome, guide and licence page through `BrandMark`. Only the matte outside the source's rounded blue square is removed. `pubspec.yaml` includes this derived asset. The previous hand-drawn mark remains in Git history; it is no longer the current app identity.

After Flutter starts, `BrandLaunch` traces a simplified stylized DS construction while its scanning brackets pulse in and out, then fades into the actual selected PNG. The 1.9-second overlay blocks input while the workspace initializes underneath; reduced-motion users skip it. It is distinct from Android's earlier system splash vector. The launch/theme source passed DartPad analysis and the motion bounds passed a DDC/Node smoke; widget tests for reveal, input, short screens and reduced motion are written but unrun. Real timing, accessibility, input blocking and device appearance remain unverified.

Android's manifest still uses `@mipmap/ic_launcher` and retains application ID `com.zamcan.desksuite`:

- Five legacy `mipmap-*` PNGs use the selected artwork at 48, 72, 96, 144 and 192 pixels.
- Android 8+ adaptive resources use a full-bleed sapphire background and a raster foreground. The selected artwork is centered in the 66/108 adaptive safe square. Its original rounded surface and border remain part of the artwork, so the adaptive result may look like a nested badge with some launcher masks.
- The Android 13 themed icon is a **simplified monochrome DS and scanning-frame vector**, not the detailed full-color artwork. The launch screen uses a separate simplified color vector: Android's splash specification calls for a vector icon, and a detailed raster would not preserve its small details in the system mask. Its paths are scaled around the center to fit the splash's documented inner circular safe area.
- Both light/dark v31 launch themes and earlier launch backgrounds point at the new simplified vector. These are distinct adaptations of the approved PNG, not pixel-identical recreations.

Regenerate the raster assets using Python 3 and Pillow (no Flutter/Android toolchain required):

```sh
python3 tools/generate_brand_assets.py
python3 tools/test_brand_assets.py
```

The corner-matte procedure is deliberately specific to this source image; if the canonical source changes, review the matte, safe zone, asset hash and tests rather than assuming it works for an arbitrary image. The test regenerates into a temporary directory and compares bytes produced by the installed Pillow version; PNG compression or resampling can differ across Pillow versions. Inspect the PNGs and XML before committing. Host checks parsed all resource XML, verified asset dimensions/safe-square placement and regenerated identical bytes under the installed Pillow; they did **not** compile Android resources or exercise real adaptive masks, themed icons, Flutter asset loading, splash behavior or small-size appearance on an Android device. Verify all of these with the owner's existing tools before release.

`tools/generate_practice_documents.py` separately regenerates fictional page/design samples using Python, Pillow, NumPy and locally available DejaVu Sans fonts. It does not regenerate the separately supplied synthetic `practice-photo.jpg`.
