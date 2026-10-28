#!/usr/bin/env python3
"""Exercise user-local launcher generation without an installed Linux app."""
import os
import shlex
import shutil
import subprocess
import tempfile
import time
import unittest
from pathlib import Path

from install_linux_launcher import MARK, app_id_from_runner, desktop_exec, install


class LinuxLauncherTest(unittest.TestCase):
    def test_app_id_is_read_from_generated_runner(self):
        with tempfile.TemporaryDirectory(prefix='desksuite-runner-') as temp:
            root = Path(temp)
            (root / 'linux').mkdir()
            (root / 'linux/CMakeLists.txt').write_text(
                'set(APPLICATION_ID "com.zamcan.desksuite.desksuite")\n')
            self.assertEqual(app_id_from_runner(root), 'com.zamcan.desksuite.desksuite')

    def test_install_and_real_gio_launch_with_quoted_path(self):
        with tempfile.TemporaryDirectory(prefix='desksuite-launcher-') as temp:
            root = Path(temp)
            folder = root / 'bundle space $cash "quote" \\slash `tick`'
            folder.mkdir()
            executable = folder / 'desksuite'
            marker = root / 'launched'
            executable.write_text(f'#!/bin/sh\nprintf launched > {shlex.quote(str(marker))}\n')
            executable.chmod(0o755)
            app_id = 'com.zamcan.desksuite.desksuite'
            desktop, icon = install(executable, root / 'xdg-data', app_id)
            text = desktop.read_text()
            self.assertIn(f'Icon={app_id}\n', text)
            self.assertIn(f'Exec={desktop_exec(executable.resolve())}\n', text)
            self.assertEqual(icon.read_bytes(), MARK.read_bytes())
            if shutil.which('gio'):
                subprocess.run(['gio', 'launch', str(desktop)], check=True, timeout=10)
                deadline = time.monotonic() + 3
                while not marker.exists() and time.monotonic() < deadline:
                    time.sleep(.02)
                self.assertEqual(marker.read_text(), 'launched')

    def test_rejects_paths_that_misparse_and_invalid_app_ids(self):
        with tempfile.TemporaryDirectory(prefix='desksuite-invalid-') as temp:
            root = Path(temp)
            for name in ['bad%path', 'bad=path', 'bad\npath']:
                with self.assertRaises(ValueError):
                    desktop_exec(root / name)
            executable = root / 'desksuite'
            executable.write_text('not executable')
            with self.assertRaises(ValueError):
                install(executable, root / 'data', 'com.zamcan.desksuite')
            executable.chmod(0o755)
            with self.assertRaises(ValueError):
                install(executable, root / 'data', '../not-an-app-id')
            with self.assertRaises(ValueError):
                install(executable, Path('relative-data'), 'com.zamcan.desksuite')


if __name__ == '__main__':
    unittest.main(verbosity=2)
