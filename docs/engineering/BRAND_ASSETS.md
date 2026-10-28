# Brand asset sources and regeneration

The owner selected the dimensional blue DS, scan-frame, document/image and pen artwork on 2026-10-28. The **canonical source** is the original AI-generated raster `assets/brand/desksuite-icon-source.png` (1254 × 1254 RGB; SHA-256 `92e47c28fb5cadb71bd779153c831c5f65923d0e029b4c37a38cb08b68feece2`). It is preserved unchanged for regeneration and is not itself bundled into Flutter. Do not claim trademark clearance or exclusive ownership without a separate review.

The generated `assets/brand/desksuite-mark.png` is a 512 × 512 RGBA version used by the in-app sidebar, startup, welcome, guide and licence page through `BrandMark`. Only the matte outside the source's rounded blue square is removed. `pubspec.yaml` includes this derived asset. The previous hand-drawn mark remains in Git history; it is no longer the current app identity. The attachment `DeskSuite-scan-frame-choice.png` supplied by the owner has the same SHA-256 as the canonical source.

## Earlier candidates as section identities

The six *other* available designs have been preserved unchanged in `assets/brand/section-sources/` and resized to 256 × 256 assets in `assets/brand/sections/`. These are **internal illustrations**, not alternative app logos. They are used in the Home tool cards and matching section title bars; Scan, Photo, Text, Office and Design images are also used on relevant guide cards. The local original filenames and their current assignments are:

| Earlier candidate | Internal illustration | Home destination |
| --- | --- | --- |
| `01-sapphire-scan.png` | `scan.png` | Scan documents |
| `03-indigo-orbit.png` | `photo.png` | Photo Studio |
| `DeskSuite-creative-suite-icon.png` | `text.png` | Text extraction |
| `DeskSuite-scan-frame-alternative.png` | `office.png` | Document converter |
| `DeskSuite-symbolic-logo.png` | `design.png` | Creative Studio |
| `02-emerald-stack.png` | `projects.png` | Files & Projects |

The existing sapphire, indigo and emerald accents are part of those earlier illustrations, not separate app themes; shared cards, text and chrome still use the coordinated DeskSuite palette. The black matte on the RGB Office alternative is removed using the same blue-surface rule as the selected icon; the other artwork already has alpha. Full-size candidate sources are not declared Flutter assets. Adjacent text names the destinations; images are decorative for accessibility and have a fallback icon. The corresponding Flutter widget/navigation tests are written but have not run here.

## Desktop launchers

- `assets/brand/desksuite-windows.ico` is generated solely from the selected in-app mark at 16, 20, 24, 32, 40, 48, 64, 96, 128 and 256 pixels. The identical checked-in `windows/runner/resources/app_icon.ico` is the Flutter Windows runner's default resource path. The rest of the Windows runner is not checked in. After generating the runner, copy the ICO to that path again, particularly if `flutter create --overwrite` was used. No Windows build, taskbar or desktop shortcut was verified here.
- `tools/install_linux_launcher.py` can create a **user-local** desktop entry and selected PNG icon for an existing complete Linux bundle. It reads the GTK `APPLICATION_ID` from the generated runner, or accepts `--app-id`. It does not build, install system-wide, move a bundle or download anything. Paths with `=`, `%` or control characters are rejected; keep the bundle in a stable path. A host test launched a fictional executable through GIO with spaces, quotes, dollar signs, backticks and backslashes in its path, but no actual DeskSuite Linux build was tested. See [development and local builds](../DEVELOPMENT.md).


## Startup and Android

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
python3 tools/test_linux_launcher.py
```

The corner-matte procedure is deliberately specific to this source image; if the canonical source changes, review the matte, safe zone, asset hash and tests rather than assuming it works for an arbitrary image. The test regenerates into a temporary directory and compares bytes produced by the installed Pillow version; PNG compression or resampling can differ across Pillow versions. Inspect the PNGs and XML before committing. Host checks parsed all resource XML, verified asset dimensions/safe-square placement, checked every ICO frame against a resize of the selected mark and regenerated identical bytes under the installed Pillow. They did **not** compile Android resources or exercise real adaptive masks, themed icons, Flutter asset loading, splash behavior, Windows resources or small-size appearance on a device. Verify all of these with the owner's existing tools before release.

`tools/generate_practice_documents.py` separately regenerates fictional page/design samples using Python, Pillow, NumPy and locally available DejaVu Sans fonts. It does not regenerate the separately supplied synthetic `practice-photo.jpg`.
