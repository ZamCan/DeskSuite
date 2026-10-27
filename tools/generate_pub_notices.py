#!/usr/bin/env python3
"""Collect root-level notices for locked hosted Pub packages, without network access.

Run after `flutter pub get`, then review diffs and native Gradle/CocoaPods
notices separately. This is an inventory, not a legal opinion or full binary
licence audit. Only the generated pubspec.lock indentation is supported.
"""
import os
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
cache = Path(os.environ.get('PUB_CACHE', Path.home() / '.pub-cache')) / 'hosted' / 'pub.dev'
lock = (ROOT / 'pubspec.lock').read_text(encoding='utf-8')
blocks = re.findall(r'^  ([a-zA-Z0-9_]+):\n(.*?)(?=^  [a-zA-Z0-9_]+:\n|^sdks:)', lock, re.M | re.S)
if not blocks:
    sys.exit('No package blocks found in pubspec.lock; check its format.')
sections = []
missing = []
package_count = 0
for name, block in blocks:
    source = re.search(r'^    source: (\S+)\s*$', block, re.M)
    version = re.search(r'^    version: "?([^"\n]+)"?\s*$', block, re.M)
    dependency = re.search(r'^    dependency: (.+?)\s*$', block, re.M)
    if not source or not version or not dependency:
        sys.exit(f'Could not parse locked package {name}.')
    if source.group(1) != 'hosted':
        continue
    ver = version.group(1).strip().strip('"')
    package = cache / f'{name}-{ver}'
    if not package.is_dir():
        missing.append(str(package))
        continue
    notices = sorted(
        p for p in package.iterdir()
        if p.is_file() and p.name.lower().startswith(('license', 'licence', 'notice', 'copying'))
    )
    if not notices:
        missing.append(f'{package} (no root notice file)')
        continue
    package_count += 1
    sections.append(f'\n{"=" * 80}\n{name} {ver} ({dependency.group(1)})\n{"=" * 80}\n')
    for notice in notices:
        sections.append(f'\n--- {notice.name} ---\n\n{notice.read_text(encoding="utf-8").rstrip()}\n')
if missing:
    sys.exit('Notices could not be collected:\n' + '\n'.join(missing))
header = (
    'ROOT-LEVEL LICENCE AND NOTICE FILES FOR HOSTED PUB PACKAGES\n'
    'Generated from pubspec.lock and the local Pub cache; includes dev and platform packages.\n'
    'Not all packages necessarily ship on each platform. This does not cover SDK,\n'
    'nested, Android Gradle, OS, binary, CocoaPods, or system dependencies.\n'
    'See THIRD_PARTY_NOTICES.md and review the actual distribution separately.\n'
)
output = ROOT / 'third_party' / 'pub-packages.LICENSES.txt'
output.write_text(header + ''.join(sections), encoding='utf-8')
print(f'Collected root-level notices for {package_count} hosted packages into {output.relative_to(ROOT)}')
