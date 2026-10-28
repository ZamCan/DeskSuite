#!/usr/bin/env python3
"""Build the in-app Office renderer notice from reviewed local text files."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
NOTICES = ROOT / 'third_party' / 'opendocument-core'
OUTPUT = ROOT / 'assets' / 'licenses' / 'office-engine-notices.txt'


def main():
    files = sorted(p for p in NOTICES.iterdir() if p.suffix in ('.txt', '.md'))
    if not files:
        raise SystemExit('No Office renderer notices found')
    sections = [
        'DeskSuite experimental Office preview: OpenDocument.core 7.6.1 and dependencies',
        'Source, modification, hashes and release-audit limitations: '
        'https://github.com/ZamCan/DeskSuite (third_party/odr-source and '
        'docs/engineering/OFFICE_SUPPORT.md).',
    ]
    for file in files:
        sections.append(f'\n===== {file.name} =====\n\n{file.read_text(encoding="utf-8")}')
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text('\n'.join(sections) + '\n', encoding='utf-8')
    print(f'Wrote {OUTPUT.relative_to(ROOT)} from {len(files)} notice files')


if __name__ == '__main__':
    main()
