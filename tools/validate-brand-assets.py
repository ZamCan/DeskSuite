#!/usr/bin/env python3
"""Check the owner-selected DeskSuite mark and native/desktop asset references.

This uses only the Python standard library so the existing CI check can run
without installing tools. It validates files and references, not OS rendering.
"""
import base64
import hashlib
from pathlib import Path
import struct
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
BRAND = ROOT / 'assets/brand'
RES = ROOT / 'android/app/src/main/res'
ANDROID = '{http://schemas.android.com/apk/res/android}'
SVG = '{http://www.w3.org/2000/svg}'
XLINK = '{http://www.w3.org/1999/xlink}'
SELECTED_SHA256 = '92e47c28fb5cadb71bd779153c831c5f65923d0e029b4c37a38cb08b68feece2'


def require(condition, message):
    if not condition:
        raise SystemExit(f'Brand asset validation failed: {message}')


def png_size(path):
    data = path.read_bytes()
    require(data.startswith(b'\x89PNG\r\n\x1a\n'), f'{path} is not PNG')
    require(len(data) >= 24 and data[12:16] == b'IHDR', f'{path} lacks IHDR')
    return struct.unpack('>II', data[16:24])


source = BRAND / 'desksuite-icon-source.png'
require(hashlib.sha256(source.read_bytes()).hexdigest() == SELECTED_SHA256,
        'owner-selected source artwork changed')
mark = BRAND / 'desksuite-mark.png'
require(png_size(mark) == (512, 512), 'in-app selected mark dimensions')

# The AppImage workflow requires an SVG filename. Its self-contained image
# must be the exact selected PNG, not the retired warm logo or a network URL.
svg = ET.parse(BRAND / 'desksuite-app-icon.svg').getroot()
require(svg.tag == SVG + 'svg' and svg.get('viewBox') == '0 0 512 512',
        'AppImage SVG wrapper is invalid')
image = svg.find(SVG + 'image')
require(image is not None, 'AppImage SVG has no embedded image')
href = image.get(XLINK + 'href', '')
require(href.startswith('data:image/png;base64,'), 'AppImage icon is not local PNG data')
try:
    embedded = base64.b64decode(href.split(',', 1)[1], validate=True)
except (ValueError, IndexError) as error:
    raise SystemExit(f'Brand asset validation failed: invalid SVG image: {error}')
require(embedded == mark.read_bytes(), 'AppImage icon differs from selected mark')

ico = (BRAND / 'desksuite-windows.ico').read_bytes()
require(ico[:4] == b'\x00\x00\x01\x00', 'Windows icon is not ICO')
require(ico == (ROOT / 'windows/runner/resources/app_icon.ico').read_bytes(),
        'Windows runner icon differs from selected mark')
manifest = (ROOT / 'android/app/src/main/AndroidManifest.xml').read_text(encoding='utf-8')
require('android:icon="@mipmap/ic_launcher"' in manifest, 'manifest icon reference changed')
for density, side in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96),
                      ('xxhdpi', 144), ('xxxhdpi', 192)]:
    require(png_size(RES / f'mipmap-{density}/ic_launcher.png') == (side, side),
            f'wrong {density} legacy launcher dimensions')
require(png_size(RES / 'drawable-nodpi/ic_launcher_foreground.png') == (432, 432),
        'adaptive foreground dimensions')
require(png_size(RES / 'drawable-nodpi/ic_launcher_background.png') == (432, 432),
        'adaptive background dimensions')
require(not (RES / 'drawable/ic_launcher_foreground.xml').exists(),
        'obsolete foreground competes with the selected raster')
for version in ('mipmap-anydpi-v26', 'mipmap-anydpi-v33'):
    adaptive = ET.parse(RES / version / 'ic_launcher.xml').getroot()
    require(adaptive.tag == 'adaptive-icon', f'{version}: not adaptive icon')
    require(adaptive.find('foreground').get(ANDROID + 'drawable') == '@drawable/ic_launcher_foreground',
            f'{version}: wrong foreground')
    require(adaptive.find('background').get(ANDROID + 'drawable') == '@drawable/ic_launcher_background',
            f'{version}: wrong background')
    if version.endswith('v33'):
        require(adaptive.find('monochrome').get(ANDROID + 'drawable') == '@drawable/ic_launcher_monochrome',
                'wrong monochrome icon')
for path in ('drawable/ic_launcher_monochrome.xml', 'drawable/splash_icon.xml',
             'drawable/launch_background.xml', 'drawable-v21/launch_background.xml',
             'values-v31/styles.xml', 'values-night-v31/styles.xml', 'values/launcher_colors.xml'):
    ET.parse(RES / path)
print('Selected DeskSuite mark and Android/desktop resource references are consistent.')
