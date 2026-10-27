#!/usr/bin/env python3
"""Regenerate Android and transparent PNG assets from the checked-in SVG.

Requires Python 3, Pillow, and ImageMagick 7 (the `magick` command).
This script is a developer utility, not an application/build dependency.
"""
from pathlib import Path
import shutil
import subprocess
import xml.etree.ElementTree as ET
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SVG = ROOT / 'assets/brand/desksuite-mark.svg'
PNG = ROOT / 'assets/brand/desksuite-mark.png'
RES = ROOT / 'android/app/src/main/res'
if not shutil.which('magick'):
    raise SystemExit('ImageMagick 7 `magick` is required to render the SVG.')

ns = {'svg': 'http://www.w3.org/2000/svg'}
xml = ET.parse(SVG).getroot()
paths = xml.findall('.//svg:path', ns)
rect = xml.find('.//svg:rect', ns)
if len(paths) != 2 or rect is None:
    raise SystemExit('The master SVG structure changed; review the Android vector generator.')

# The mark is scaled by 1.25 around the centre in both the SVG and vector.
def vector(monochrome=False):
    pieces = ['<?xml version="1.0" encoding="utf-8"?>',
              '<vector xmlns:android="http://schemas.android.com/apk/res/android"',
              '    android:width="108dp" android:height="108dp"',
              '    android:viewportWidth="512" android:viewportHeight="512">',
              '  <group android:pivotX="256" android:pivotY="256" android:scaleX="1.25" android:scaleY="1.25">']
    for path in paths:
        color = '#FFFFFFFF' if monochrome else path.attrib['fill']
        rule = ' android:fillType="evenOdd"' if path.attrib.get('fill-rule') == 'evenodd' else ''
        pieces.append(f'    <path android:fillColor="{color}"{rule} android:pathData="{path.attrib["d"]}" />')
    color = '#FFFFFFFF' if monochrome else rect.attrib['fill']
    pieces.append(f'    <path android:fillColor="{color}" android:pathData="M205,273 H237 A5,5 0,0 1,237,283 H205 A5,5 0,0 1,205,273 Z" />')
    pieces += ['  </group>', '</vector>', '']
    return '\n'.join(pieces)

(RES / 'drawable').mkdir(parents=True, exist_ok=True)
(RES / 'drawable/ic_launcher_foreground.xml').write_text(vector(), encoding='utf-8')
(RES / 'drawable/ic_launcher_monochrome.xml').write_text(vector(True), encoding='utf-8')
(RES / 'values').mkdir(parents=True, exist_ok=True)
(RES / 'values/launcher_colors.xml').write_text('<?xml version="1.0" encoding="utf-8"?>\n<resources><color name="launcher_background">#292824</color></resources>\n', encoding='utf-8')
for folder, monochrome in [('mipmap-anydpi-v26', False), ('mipmap-anydpi-v33', True)]:
    path = RES / folder
    path.mkdir(parents=True, exist_ok=True)
    line = '    <monochrome android:drawable="@drawable/ic_launcher_monochrome" />\n' if monochrome else ''
    (path / 'ic_launcher.xml').write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/launcher_background" />\n'
        '    <foreground android:drawable="@drawable/ic_launcher_foreground" />\n'
        + line + '</adaptive-icon>\n', encoding='utf-8')

# Launch background uses the same adaptive foreground and warm-ink surface.
launch = ('<?xml version="1.0" encoding="utf-8"?>\n'
          '<layer-list xmlns:android="http://schemas.android.com/apk/res/android">\n'
          '    <item android:drawable="@color/launcher_background" />\n'
          '    <item android:drawable="@drawable/ic_launcher_foreground" android:gravity="center" />\n'
          '</layer-list>\n')
for folder in ['drawable', 'drawable-v21']:
    (RES / folder).mkdir(parents=True, exist_ok=True)
    (RES / folder / 'launch_background.xml').write_text(launch, encoding='utf-8')

# Render the vector at high resolution, retain transparency in the brand PNG,
# and downsample legacy icons from the same master with an opaque dark surface.
subprocess.run(['magick', '-background', 'none', '-density', '192', str(SVG), '-resize', '1024x1024', str(PNG)], check=True)
mark = Image.open(PNG).convert('RGBA').resize((1024, 1024), Image.Resampling.LANCZOS)
mask = Image.new('L', (1024, 1024), 0)
ImageDraw.Draw(mask).rounded_rectangle((0, 0, 1023, 1023), radius=220, fill=255)
background = Image.new('RGBA', (1024, 1024), (41, 40, 36, 255))
background.putalpha(mask)
background.alpha_composite(mark)
for density, size in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)]:
    out = RES / ('mipmap-' + density)
    out.mkdir(parents=True, exist_ok=True)
    background.resize((size, size), Image.Resampling.LANCZOS).save(out / 'ic_launcher.png', optimize=True)
print('Generated brand PNG, Android adaptive/monochrome vectors, legacy icons and splash backgrounds.')
