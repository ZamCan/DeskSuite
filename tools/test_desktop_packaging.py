#!/usr/bin/env python3
"""Check desktop packaging references without running any build or packaging."""
import configparser
import hashlib
import re
import shutil
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFINITIONS = [ROOT / '.github/workflows/build.yml',
               ROOT / 'ci/android-testing-and-release.yml.example']


class DesktopPackagingTest(unittest.TestCase):
    def test_windows_copy_is_after_create_and_before_build(self):
        for path in DEFINITIONS:
            source = path.read_text()
            create = source.index('flutter create --project-name desksuite --org com.zamcan.desksuite --platforms=windows .')
            apply = source.index('Copy-Item -Force assets/brand/desksuite-windows.ico windows/runner/resources/app_icon.ico')
            build = source.index('flutter build windows --release')
            self.assertLess(create, apply, str(path))
            self.assertLess(apply, build, str(path))
            self.assertEqual(
                (ROOT / 'assets/brand/desksuite-windows.ico').read_bytes(),
                (ROOT / 'windows/runner/resources/app_icon.ico').read_bytes())

    def test_linux_definitions_include_secure_storage_headers(self):
        # dart_pdf_editor brings flutter_secure_storage_linux transitively.
        # This is a source-definition check, not a successful Linux build.
        for path in DEFINITIONS:
            source = path.read_text()
            self.assertIn('libsecret-1-dev', source, str(path))
        self.assertIn('flutter_secure_storage_linux:', (ROOT / 'pubspec.lock').read_text())

    def test_appimage_entry_names_the_selected_png(self):
        for path in DEFINITIONS:
            source = path.read_text()
            match = re.search(r"cat > AppDir/desksuite\.desktop <<'EOF'\n(.*?)\n\s+EOF", source, re.S)
            self.assertIsNotNone(match, str(path))
            content = '\n'.join(line.strip() for line in match.group(1).splitlines()) + '\n'
            entry = configparser.ConfigParser(interpolation=None)
            entry.optionxform = str
            entry.read_string(content)
            self.assertEqual(entry['Desktop Entry']['Icon'], 'desksuite')
            self.assertEqual(entry['Desktop Entry']['Exec'], 'AppRun')
            self.assertIn('cp assets/brand/desksuite-mark.png AppDir/desksuite.png', source)
            self.assertNotIn('AppDir/desksuite.svg', source)
            with tempfile.TemporaryDirectory(prefix='desksuite-appdir-') as temp:
                target = Path(temp) / (entry['Desktop Entry']['Icon'] + '.png')
                mark = ROOT / 'assets/brand/desksuite-mark.png'
                shutil.copyfile(mark, target)
                self.assertEqual(hashlib.sha256(mark.read_bytes()).digest(),
                                 hashlib.sha256(target.read_bytes()).digest())


if __name__ == '__main__':
    unittest.main(verbosity=2)
