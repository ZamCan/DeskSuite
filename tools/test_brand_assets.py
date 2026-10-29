#!/usr/bin/env python3
"""Host-side structural and reproducibility checks for the brand assets.

Requires Python 3 and Pillow. Does not compile Android resources or run Flutter.
"""
import hashlib
import math
import re
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from generate_brand_assets import (  # noqa: E402
    SECTION_NAMES, WINDOWS_SIZES, generate, generate_section_artwork,
    generate_windows_icon, generate_appimage_icon,
)

RES = ROOT / 'android/app/src/main/res'
ANDROID = '{http://schemas.android.com/apk/res/android}'
SOURCE_HASH = '92e47c28fb5cadb71bd779153c831c5f65923d0e029b4c37a38cb08b68feece2'
SECTION_HASHES = {
    'design': 'd170a154d2236fe3886713a232103ec49072a4ee0f7791c0e328dcd34ed16e3c',
    'office': 'e12a968b6a4db15e29360f3aa57eec905c8301d61a0dfec132a1ced5bc1854ed',
    'photo': '7f8e28d42bd20564eeabc6d99d3f18b4163ee9c41c114b942997ea2ab5be900e',
    'projects': '75263bc475b06b9344b2178269985988a46b52e41231d360fb74dffddc89f757',
    'scan': 'a80eaecb51c0dc3d7dfa645b36766f47bae052e9b29cc6673d01c1915d84ccf8',
    'text': '50e02d46759f25ef133dac5b0a1e4ea1cf2bd409e275223acf4d7def548529ed',
}


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
        manifest = ET.parse(ROOT / 'android/app/src/main/AndroidManifest.xml').getroot()
        application = manifest.find('application')
        self.assertEqual(application.get(ANDROID + 'label'), 'DeskSuite')
        self.assertEqual(application.get(ANDROID + 'icon'), '@mipmap/ic_launcher')
        self.assertEqual(application.get(ANDROID + 'roundIcon'), '@mipmap/ic_launcher')
        launcher = application.find('activity/intent-filter')
        self.assertEqual(launcher.find('action').get(ANDROID + 'name'), 'android.intent.action.MAIN')
        self.assertEqual(launcher.find('category').get(ANDROID + 'name'), 'android.intent.category.LAUNCHER')
        self.assertIn("deskSuiteBrandAsset = 'assets/brand/desksuite-mark.png'",
                      (ROOT / 'lib/app/theme.dart').read_text())
        self.assertIn('child: BrandMark(size: size)', (ROOT / 'lib/app/brand_launch.dart').read_text())
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
        self.assertIn('assets/brand/', (ROOT / 'pubspec.yaml').read_text())

    def test_splash_strokes_fit_inside_the_android_safe_circle(self):
        vector = ET.parse(RES / 'drawable/splash_icon.xml').getroot()
        self.assertEqual(vector.get(ANDROID + 'viewportWidth'), '1024')
        self.assertEqual(vector.get(ANDROID + 'viewportHeight'), '1024')
        group = vector.find('group')
        self.assertIsNotNone(group)
        self.assertEqual(float(group.get(ANDROID + 'pivotX')), 512)
        self.assertEqual(float(group.get(ANDROID + 'pivotY')), 512)
        sx = float(group.get(ANDROID + 'scaleX'))
        self.assertGreater(sx, 0)
        self.assertLess(sx, 1)
        self.assertEqual(sx, float(group.get(ANDROID + 'scaleY')))
        paths = group.findall('path')
        self.assertTrue(paths)
        self.assertEqual(len(list(vector.iter('path'))), len(paths))
        for path in paths:
            data = path.get(ANDROID + 'pathData')
            # This conservative test supports absolute M/L/Q/C/Z only. Bezier
            # curves lie in their control-point hull; include the stroke radius.
            self.assertTrue(all(c in 'MLQCZ' for c in re.findall(r'[A-Za-z]', data)))
            values = [float(v) for v in re.findall(r'-?\d+(?:\.\d+)?', data)]
            self.assertEqual(len(values) % 2, 0)
            stroke = float(path.get(ANDROID + 'strokeWidth')) / 2
            extent = max(math.hypot(x - 512, y - 512) + stroke
                         for x, y in zip(values[::2], values[1::2])) * sx
            # Splash specification: 160/240 or 192/288 diameter.
            self.assertLessEqual(extent, 1024 / 3)

    def test_windows_icon_contains_only_the_selected_mark_in_all_sizes(self):
        with Image.open(ROOT / 'assets/brand/desksuite-mark.png') as source:
            mark = source.convert('RGBA')
        icon_path = ROOT / 'assets/brand/desksuite-windows.ico'
        self.assertEqual(sha(icon_path), sha(ROOT / 'windows/runner/resources/app_icon.ico'))
        with Image.open(icon_path) as ico:
            self.assertEqual(ico.ico.sizes(), {(side, side) for side in WINDOWS_SIZES})
            for side in WINDOWS_SIZES:
                expected = mark.resize((side, side), Image.Resampling.LANCZOS)
                actual = ico.ico.getimage((side, side)).convert('RGBA')
                self.assertEqual(actual.tobytes(), expected.tobytes(), side)

    def test_section_originals_and_bundled_images(self):
        self.assertEqual(set(SECTION_NAMES), set(SECTION_HASHES))
        self.assertIn('assets/brand/sections/', (ROOT / 'pubspec.yaml').read_text())
        registry = (ROOT / 'lib/app/section_artwork.dart').read_text()
        for name in SECTION_NAMES:
            original = ROOT / f'assets/brand/section-sources/{name}-original.png'
            self.assertEqual(sha(original), SECTION_HASHES[name], name)
            image_path = ROOT / f'assets/brand/sections/{name}.png'
            with Image.open(image_path) as image:
                self.assertEqual(image.size, (256, 256), name)
                self.assertEqual(image.mode, 'RGBA', name)
                self.assertEqual(image.getpixel((0, 0))[3], 0, name)
                self.assertEqual(image.getpixel((128, 128))[3], 255, name)
            self.assertIn(f'assets/brand/sections/{name}.png', registry)

    def test_each_home_card_and_section_uses_its_assigned_art(self):
        screen = (ROOT / 'lib/workspace/workspace_screen.dart').read_text()
        widgets = (ROOT / 'lib/workspace/workspace_widgets.dart').read_text()
        assignments = [
            ('scan', 'scan', 'scans'), ('photo', 'photo', 'photos'),
            ('text', 'text', 'text'), ('converter', 'office', 'office'),
            ('design', 'design', 'design'), ('projects', 'projects', 'projects'),
        ]
        self.assertIn('final artwork = artworkForSection(section)', widgets)
        self.assertIn('onTap: () => onNavigate(section)', widgets)
        self.assertIn('final artwork = artworkForSection(value)', widgets)
        self.assertIn('onTap: () => onNavigate(value)', widgets)
        self.assertIn('artworkForSection(_section)', screen)
        for key, art, section in assignments:
            self.assertIn(f'WorkspaceSection.{section} => SectionArt.{art}', widgets)
            pattern = (r'WorkspaceToolCard\((?:(?!WorkspaceToolCard\().)*?'
                       + re.escape(f"key: const Key('home-open-{key}')")
                       + r'(?:(?!WorkspaceToolCard\().)*?'
                       + re.escape(f'section: WorkspaceSection.{section}')
                       + r'(?:(?!WorkspaceToolCard\().)*?'
                       + re.escape('onNavigate: _navigate'))
            self.assertRegex(screen, re.compile(pattern, re.S), key)

    def test_home_search_only_indexes_real_shortcuts(self):
        screen = (ROOT / 'lib/workspace/workspace_screen.dart').read_text()
        search = (ROOT / 'lib/workspace/shortcut_search.dart').read_text()
        registry = search.split('const homeShortcutSearchTerms', 1)[1].split('};', 1)[0]
        sections = set(re.findall(r'WorkspaceSection\.([a-zA-Z]+)', registry))
        cards = set(re.findall(
            r'key: const Key\(\'home-open-[^\']+\'\),\s*section: WorkspaceSection\.([a-zA-Z]+)',
            screen,
        ))
        filters = set(re.findall(
            r'matchesHomeShortcut\(\s*WorkspaceSection\.([a-zA-Z]+)\s*,\s*_shortcutQuery\s*,?\s*\)',
            screen,
        ))
        self.assertEqual(sections, cards)
        self.assertEqual(sections, filters)
        self.assertEqual(len(sections), 7)
        self.assertIn("Key('home-shortcut-empty')", screen)
        self.assertIn("Key('home-clear-shortcut-search')", screen)

    def test_section_pages_map_every_enum_to_the_real_page(self):
        screen = (ROOT / 'lib/workspace/workspace_screen.dart').read_text()
        widgets = (ROOT / 'lib/workspace/workspace_widgets.dart').read_text()
        enum = re.search(r'enum WorkspaceSection\s*\{([^}]+)\}', widgets, re.S).group(1)
        enum = re.sub(r'//[^\n]*', '', enum)
        sections = re.findall(r'\b[a-z][a-zA-Z0-9]*\b', enum)
        method = screen.split('Widget _sectionPage(WorkspaceSection section)', 1)[1]
        method = method.split('\n  @override', 1)[0]
        cases = list(re.finditer(r'^\s*WorkspaceSection\.([a-zA-Z]+)\s*=>', method, re.M))
        self.assertEqual(len(cases), len(sections))
        self.assertEqual({match.group(1) for match in cases}, set(sections))
        expected = {
            'workspace': '_workspace()', 'projects': '_projectPage()',
            'settings': '_settings()', 'design': 'CreativeStudioPage(',
            'photos': 'legacy.PhotoPage(', 'notes': 'legacy.NotesPage(',
            'printing': 'legacy.PrintPage(', 'business': 'legacy.BusinessPage(',
            'scans': 'ScanStudioPage(', 'guide': 'GettingStartedPage(',
            'conversions': 'ConversionCatalogPage(', 'text': 'TextExtractionPage(',
            'office': 'OfficeConvertPage(', 'pdfStudio': 'PdfStudioPage(',
        }
        self.assertEqual(set(expected), set(sections))
        for index, match in enumerate(cases):
            end = cases[index + 1].start() if index + 1 < len(cases) else len(method)
            self.assertIn(expected[match.group(1)], method[match.start():end])
        self.assertIn('for (final section in WorkspaceSection.values)', screen)
        self.assertIn('child: _sectionPage(section)', screen)
        self.assertIn('index: _section.index', screen)

    def test_guide_artwork_is_assigned_to_matching_actions(self):
        guide = (ROOT / 'lib/workspace/getting_started_page.dart').read_text()
        assignments = [
            ('extract-text', 'text', 'onText'),
            ('convert-office', 'office', 'onOffice'),
            ('clean-page', 'scan', 'onScan'),
            ('scan-pages', 'scan', 'onScan'),
            ('correct-page', 'scan', 'onScan'),
            ('clean-photo', 'photo', 'onPhoto'),
            ('resize-image', 'photo', 'onPhoto'),
            ('edit-design', 'design', 'onEditableExample'),
        ]
        for key, art, action in assignments:
            pattern = (r'_GuideCard\((?:(?!_GuideCard\().)*?'
                       + re.escape(f"key: const Key('guide-{key}')")
                       + r'(?:(?!_GuideCard\().)*?'
                       + re.escape(f'artwork: SectionArt.{art}')
                       + r'(?:(?!_GuideCard\().)*?'
                       + re.escape(f'onPressed: {action}'))
            self.assertRegex(guide, re.compile(pattern, re.S), key)

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
            windows_icon = temp / 'app_icon.ico'
            generate_windows_icon(brand, windows_icon)
            self.assertEqual(sha(ROOT / 'assets/brand/desksuite-windows.ico'), sha(windows_icon))
            self.assertEqual(sha(ROOT / 'windows/runner/resources/app_icon.ico'), sha(windows_icon))
            appimage = temp / 'icon.svg'
            generate_appimage_icon(brand, appimage)
            self.assertEqual(sha(ROOT / 'assets/brand/desksuite-app-icon.svg'), sha(appimage))
            sections = temp / 'sections'
            generate_section_artwork(ROOT / 'assets/brand/section-sources', sections)
            for name in SECTION_NAMES:
                self.assertEqual(sha(ROOT / f'assets/brand/sections/{name}.png'),
                                 sha(sections / f'{name}.png'), name)


if __name__ == '__main__':
    unittest.main(verbosity=2)
