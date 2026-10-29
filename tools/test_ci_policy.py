#!/usr/bin/env python3
"""Check that ordinary CI keeps tests but never packages automatically.

This is a structural policy check, not a build or a GitHub Actions execution.
It intentionally uses only the Python standard library.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = ROOT / '.github/workflows/build.yml'
OPT_IN = "if: ${{ github.event_name == 'workflow_dispatch' && inputs.package_release }}"
ANDROID_RELEASE = "if: ${{ (github.event_name == 'workflow_dispatch' && inputs.package_release) || (github.event_name == 'push' && github.ref == 'refs/heads/main') }}"


def job_steps(source, job):
    marker = f'  {job}:\n'
    body = source.split(marker, 1)[1]
    # The next job starts at two spaces; steps start at six.
    lines = body.splitlines()
    steps = []
    current = []
    for line in lines:
        if line.startswith('  ') and not line.startswith('    ') and line.strip().endswith(':'):
            break
        if line.startswith('      - '):
            if current:
                steps.append('\n'.join(current))
            current = [line]
        elif current:
            current.append(line)
    if current:
        steps.append('\n'.join(current))
    return steps


class WorkflowPolicyTest(unittest.TestCase):
    def test_ordinary_push_and_pr_keep_analysis_and_tests(self):
        source = WORKFLOW.read_text()
        self.assertIn('  push:\n    branches: [main]', source)
        self.assertIn('  pull_request:\n    branches: [main]', source)
        self.assertIn('      package_release:', source)
        self.assertIn('        default: false', source)
        for job in ('android', 'windows', 'linux', 'ios'):
            steps = job_steps(source, job)
            for command in ('flutter analyze', 'flutter test'):
                matches = [step for step in steps if f'- run: {command}' in step]
                self.assertEqual(len(matches), 1, (job, command))
                self.assertNotIn('\n        if:', matches[0], (job, command))

    def test_release_build_archive_and_upload_steps_require_manual_opt_in(self):
        source = WORKFLOW.read_text()
        expected = {
            'android': ['flutter build apk --release', 'flutter build appbundle --release', 'name: desksuite-android-unsigned'],
            'windows': ['flutter build windows --release', 'Compress-Archive', 'name: desksuite-windows-x64'],
            'linux': ['flutter build linux --release', 'tar -czf desksuite-linux', 'name: Assemble AppImage directory', 'name: desksuite-linux-x64'],
            'ios': ['flutter build ios --release --no-codesign', 'ditto -c -k', 'name: desksuite-ios-unsigned-validation'],
        }
        for job, markers in expected.items():
            steps = job_steps(source, job)
            for marker in markers:
                matches = [step for step in steps if marker in step]
                self.assertEqual(len(matches), 1, (job, marker))
                expected_condition = ANDROID_RELEASE if job == 'android' else OPT_IN
                self.assertIn(expected_condition, matches[0], (job, marker))


if __name__ == '__main__':
    unittest.main(verbosity=2)
