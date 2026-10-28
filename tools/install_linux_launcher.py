#!/usr/bin/env python3
"""Install a user-local Linux launcher using the selected DeskSuite icon.

Run after creating a Linux release bundle. Keep the entire bundle together in a
stable location; rebuilding or moving it changes the executable path. This
script never installs system-wide and does not build or download anything.
"""
import argparse
import os
import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MARK = ROOT / 'assets/brand/desksuite-mark.png'
APP_ID_PATTERN = re.compile(r'[A-Za-z_][A-Za-z0-9_-]*(?:\.[A-Za-z_][A-Za-z0-9_-]*)+')


def desktop_exec(path: Path) -> str:
    """Quote an absolute executable path per the desktop-entry Exec rules."""
    value = str(path)
    # GIO does not reliably load desktop entries when %% is in the executable
    # path, even when doubled as required by the specification. Fail clearly.
    if any(char in value for char in '=%') or any(
        ord(char) < 32 or ord(char) == 127 for char in value
    ):
        raise ValueError('The executable path cannot contain =, % or control characters.')
    escaped = []
    for char in value:
        if char == '\\':
            escaped.append('\\' * 4)  # string-value escape, then Exec escape
        elif char in ('"', '$', '`'):
            escaped.append('\\' * 2 + char)
        else:
            escaped.append(char)
    return '"' + ''.join(escaped) + '"'


def app_id_from_runner(root: Path = ROOT) -> str:
    cmake = root / 'linux/CMakeLists.txt'
    if not cmake.is_file():
        raise ValueError('Create the Linux runner first or specify --app-id.')
    match = re.search(r'set\s*\(\s*APPLICATION_ID\s+"([^"]+)"\s*\)', cmake.read_text())
    if not match:
        raise ValueError('Could not read APPLICATION_ID from linux/CMakeLists.txt; specify --app-id.')
    return match.group(1)


def install(binary: Path, data_home: Path, app_id: str, mark: Path = MARK) -> tuple[Path, Path]:
    binary = binary.expanduser().resolve(strict=True)
    if not binary.is_file() or not os.access(binary, os.X_OK):
        raise ValueError('The bundle executable must be an existing executable file.')
    if not data_home.is_absolute():
        raise ValueError('The XDG data directory must be an absolute path.')
    if not APP_ID_PATTERN.fullmatch(app_id):
        raise ValueError('The application ID must be a valid dotted GTK application ID.')
    if not mark.is_file():
        raise ValueError('The selected DeskSuite PNG is missing.')
    command = desktop_exec(binary)
    icon = data_home / 'icons/hicolor/512x512/apps' / f'{app_id}.png'
    desktop = data_home / 'applications' / f'{app_id}.desktop'
    icon.parent.mkdir(parents=True, exist_ok=True)
    desktop.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(mark, icon)
    desktop.write_text(
        '[Desktop Entry]\n'
        'Type=Application\n'
        'Name=DeskSuite\n'
        'Comment=Offline-first creative and productivity workspace\n'
        f'Exec={command}\n'
        f'Icon={app_id}\n'
        'Terminal=false\n'
        'Categories=Office;Graphics;\n',
        encoding='utf-8',
    )
    return desktop, icon


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('binary', type=Path, help='Executable inside the complete Linux bundle')
    parser.add_argument('--app-id', help='GTK APPLICATION_ID; normally read from the generated runner')
    parser.add_argument('--data-home', type=Path, help='Absolute XDG data directory (default: user data home)')
    args = parser.parse_args()
    data_home = args.data_home or Path(os.environ.get('XDG_DATA_HOME') or Path.home() / '.local/share')
    try:
        desktop, icon = install(args.binary, data_home.expanduser(), args.app_id or app_id_from_runner())
    except (OSError, ValueError) as error:
        parser.exit(1, f'Could not install launcher: {error}\n')
    print(f'Installed user-local launcher: {desktop}\nInstalled selected icon: {icon}')
    print('If your desktop caches launchers, refresh it or log out and back in.')


if __name__ == '__main__':
    main()
