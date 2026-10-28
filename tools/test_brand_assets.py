#!/usr/bin/env python3
"""Host-side structural and reproducibility checks for the brand assets.

Requires Python 3 and Pillow. Does not compile Android resources or run Flutter.
"""
import hashlib
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from generate_brand_assets import generate  # noqa: E402

RES = ROOT / 'android/app/src/main/res'
ANDROID = '{http://schemas.android.com/apk/res/android}'
SOURCE_HASH = '92e47c28fb5cadb71bd779153c831c5f65923d0e029b4c37a38cb08b68feece2'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


class BrandAssetsTest(unittest.TestCase):
    def test_source_is_the_selected_image_and_derived_mark_has_clear_corners(self):
        source = ROOT / 'assets/brand/desksuite-icon-source.png'
        self.assertEqual(sha(source), SOURCE_HASH)
        with Image.open(source) as image:
            self.assertEqual(image.size, (1254, 1254))
        with Image.open(ROOT / 'assets/brand/desksuite-mark.png') as mark:
            self.assertEqual(mark.size, (512, 512))
            self.assertEqual(mark.mode, 'RGBA')
            self.assertEqual(mark.getpixel((0, 0))[3], 0)
            self.assertEqual(mark.getpixel((256, 256))[3], 255)

    def test_android_layer_geometry_and_legacy_sizes(self):
        with Image.open(RES / 'drawable-nodpi/ic_launcher_foreground.png') as foreground:
            self.assertEqual(foreground.size, (432, 432))
            self.assertEqual(foreground.mode, 'RGBA')
            # 66 dp of a 108 dp layer at 4 px/dp, centered.
            self.assertEqual(foreground.getchannel('A').getbbox(), (84, 84, 348, 348))
        with Image.open(RES / 'drawable-nodpi/ic_launcher_background.png') as bg:
            self.assertEqual(bg.size, (432, 432))
            self.assertEqual(bg.mode, 'RGB')
        for density, size in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96),
                              ('xxhdpi', 144), ('xxxhdpi', 192)]:
            with Image.open(RES / f'mipmap-{density}/ic_launcher.png') as image:
                self.assertEqual(image.size, (size, size), density)
                self.assertEqual(image.mode, 'RGBA', density)

    def test_resource_xml_points_to_current_layers_and_vector_splash(self):
        for xml in RES.rglob('*.xml'):
            ET.parse(xml)
        for folder in ['mipmap-anydpi-v26', 'mipmap-anydpi-v33']:
            root = ET.parse(RES / folder / 'ic_launcher.xml').getroot()
            self.assertEqual(root.tag, 'adaptive-icon')
            self.assertEqual(root.find('background').get(ANDROID + 'drawable'),
                             '@drawable/ic_launcher_background')
            self.assertEqual(root.find('foreground').get(ANDROID + 'drawable'),
                             '@drawable/ic_launcher_foreground')
        vector = ET.parse(RES / 'drawable/splash_icon.xml').getroot()
        mono = ET.parse(RES / 'drawable/ic_launcher_monochrome.xml').getroot()
        self.assertEqual(vector.tag, 'vector')
        self.assertEqual(mono.tag, 'vector')
        for folder in ['values-v31', 'values-night-v31']:
            root = ET.parse(RES / folder / 'styles.xml').getroot()
            items = {item.get('name'): item.text for item in root.iter('item')}
            self.assertEqual(items['android:windowSplashScreenAnimatedIcon'], '@drawable/splash_icon')
        self.assertIn('assets/brand/desksuite-mark.png', (ROOT / 'pubspec.yaml').read_text())

    def test_regeneration_is_byte_identical(self):
        outputs = [ROOT / 'assets/brand/desksuite-mark.png',
                   RES / 'drawable-nodpi/ic_launcher_foreground.png',
                   RES / 'drawable-nodpi/ic_launcher_background.png']
        outputs += [RES / f'mipmap-{d}/ic_launcher.png' for d in
                    ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']]
        with tempfile.TemporaryDirectory(prefix='desksuite-brand-check-') as temp:
            temp = Path(temp)
            brand = temp / 'desksuite-mark.png'
            res = temp / 'res'
            generate(ROOT / 'assets/brand/desksuite-icon-source.png', brand, res)
            generated = [brand, res / 'drawable-nodpi/ic_launcher_foreground.png',
                         res / 'drawable-nodpi/ic_launcher_background.png']
            generated += [res / f'mipmap-{d}/ic_launcher.png' for d in
                          ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']]
            self.assertEqual([sha(p) for p in outputs], [sha(p) for p in generated])


if __name__ == '__main__':
    unittest.main(verbosity=2)
