#!/usr/bin/env python3
"""Regenerate DeskSuite's launcher, desktop and internal artwork.

Requires Python 3 and Pillow; no Flutter or native toolchain is required.
The approved source stays untouched. Earlier candidates are used only for
in-app section illustrations. Android's generated foreground fits inside the
66/108 adaptive-icon safe square; launcher masks vary by device.
"""
from pathlib import Path
import shutil

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/brand/desksuite-icon-source.png'
BRAND = ROOT / 'assets/brand/desksuite-mark.png'
RES = ROOT / 'android/app/src/main/res'
DESKTOP_ICO = ROOT / 'assets/brand/desksuite-windows.ico'
WINDOWS_ICON = ROOT / 'windows/runner/resources/app_icon.ico'
SECTION_SOURCES = ROOT / 'assets/brand/section-sources'
SECTION_ASSETS = ROOT / 'assets/brand/sections'
SECTION_NAMES = ('scan', 'photo', 'text', 'office', 'design', 'projects')
WINDOWS_SIZES = (16, 20, 24, 32, 40, 48, 64, 96, 128, 256)


def remove_corner_matte(image: Image.Image) -> Image.Image:
    """Remove the black outside the selected rounded square, not its contents.

    The supplied image is RGB with an almost-black corner matte. Each scanline
    retains everything between the first and last blue-surface pixels. This is
    intentionally specific to the checked-in owner-selected artwork, not a
    general background-removal algorithm.
    """
    rgb = image.convert('RGB')
    width, height = rgb.size
    pixels = rgb.load()
    alpha = Image.new('L', rgb.size, 0)
    draw = ImageDraw.Draw(alpha)
    for y in range(height):
        left = 0
        while left < width and pixels[left, y][2] <= 35:
            left += 1
        right = width - 1
        while right >= left and pixels[right, y][2] <= 35:
            right -= 1
        if left > right:
            continue
        draw.line((left, y, right, y), fill=255)
    rgba = rgb.convert('RGBA')
    rgba.putalpha(alpha)
    return rgba


def background(size: int) -> Image.Image:
    """An opaque, full-bleed sapphire surface behind the adaptive foreground."""
    top = (24, 78, 174)
    bottom = (10, 35, 101)
    result = Image.new('RGB', (size, size))
    draw = ImageDraw.Draw(result)
    for y in range(size):
        mix = y / max(1, size - 1)
        color = tuple(round(a * (1 - mix) + b * mix) for a, b in zip(top, bottom))
        draw.line((0, y, size - 1, y), fill=color)
    return result


def generate(source_path: Path = SOURCE, brand_path: Path = BRAND, res: Path = RES) -> None:
    source = Image.open(source_path)
    if source.width != source.height or source.width < 512:
        raise SystemExit('The selected brand source must be a square of at least 512 px.')
    mark = remove_corner_matte(source)
    brand_path.parent.mkdir(parents=True, exist_ok=True)
    mark.resize((512, 512), Image.Resampling.LANCZOS).save(brand_path, optimize=True)

    # Legacy launchers show the selected full icon with transparent corners.
    for density, size in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96),
                          ('xxhdpi', 144), ('xxxhdpi', 192)]:
        path = res / f'mipmap-{density}' / 'ic_launcher.png'
        path.parent.mkdir(parents=True, exist_ok=True)
        mark.resize((size, size), Image.Resampling.LANCZOS).save(path, optimize=True)

    # 432 px is 108 dp at xxxhdpi. Artwork fits the central 66 dp square.
    side, safe = 432, 264
    foreground = Image.new('RGBA', (side, side), (0, 0, 0, 0))
    art = mark.resize((safe, safe), Image.Resampling.LANCZOS)
    foreground.alpha_composite(art, ((side - safe) // 2, (side - safe) // 2))
    folder = res / 'drawable-nodpi'
    folder.mkdir(parents=True, exist_ok=True)
    foreground.save(folder / 'ic_launcher_foreground.png', optimize=True)
    background(side).save(folder / 'ic_launcher_background.png', optimize=True)
    print('Regenerated the in-app mark and Android raster icon layers.')


def generate_windows_icon(brand_path: Path = BRAND, output_path: Path = DESKTOP_ICO) -> None:
    """Write a multi-size Windows ICO from the selected mark."""
    with Image.open(brand_path) as image:
        mark = image.convert('RGBA')
    output_path.parent.mkdir(parents=True, exist_ok=True)
    mark.save(output_path, format='ICO', sizes=[(size, size) for size in WINDOWS_SIZES])
    print('Regenerated the Windows multi-resolution launcher icon.')


def generate_section_artwork(source_dir: Path = SECTION_SOURCES,
                             output_dir: Path = SECTION_ASSETS) -> None:
    """Make modestly sized internal illustrations from earlier candidates.

    The 3D alternative is RGB with a black corner matte, much like the selected
    blue image; remove that matte before resizing. Other source images already
    contain alpha. Their distinctive colors and designs are retained.
    """
    output_dir.mkdir(parents=True, exist_ok=True)
    for name in SECTION_NAMES:
        source = source_dir / f'{name}-original.png'
        with Image.open(source) as image:
            if image.width != image.height or image.width < 256:
                raise ValueError(f'{source} must be a square of at least 256 px')
            artwork = remove_corner_matte(image) if name == 'office' else image.convert('RGBA')
        artwork.resize((256, 256), Image.Resampling.LANCZOS).save(
            output_dir / f'{name}.png', optimize=True)
    print('Regenerated six illustrations for in-app sections.')


if __name__ == '__main__':
    generate()
    generate_windows_icon()
    WINDOWS_ICON.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(DESKTOP_ICO, WINDOWS_ICON)
    generate_section_artwork()
