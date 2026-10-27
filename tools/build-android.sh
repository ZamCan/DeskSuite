#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "\${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail() {
  printf '\nDeskSuite build stopped: %s\n' "$1" >&2
  exit 1
}

command -v git >/dev/null 2>&1 || fail "Git is required."
if ! command -v flutter >/dev/null 2>&1; then
  cat >&2 <<'MSG'

Flutter SDK is not installed in this Termux environment.
Gradle alone cannot compile DeskSuite's Dart/Flutter application sources.

You can either:
  1. Install a compatible Flutter SDK and then rerun this script; or
  2. Push the integrated source to GitHub, open:
     https://github.com/ZamCan/DeskSuite/actions
     and download the desksuite-android artifact from a successful run.

No files have been deleted or reset by this check.
MSG
  exit 2
fi
command -v java >/dev/null 2>&1 || fail "Java is not installed or is not on PATH."

printf '\n== DeskSuite Android build ==\n'
printf 'Repository: %s\n' "$ROOT"
flutter --version
java -version

if [[ ! -d android ]]; then
  printf '\nAndroid platform files are missing; generating Android scaffolding...\n'
  flutter create --project-name desksuite --org com.zamcan.desksuite --platforms=android .
fi

printf '\n== Dependency resolution ==\n'
flutter pub get

printf '\n== Formatting ==\n'
dart format lib test

printf '\n== Static analysis ==\n'
flutter analyze

printf '\n== Tests ==\n'
flutter test

printf '\n== Release APK ==\n'
flutter build apk --release

APK="$ROOT/build/app/outputs/flutter-apk/app-release.apk"
[[ -s "$APK" ]] || fail "Flutter reported a build without producing the expected APK."

printf '\nAPK built successfully:\n%s\n' "$APK"
printf 'Size: '
du -h "$APK" | awk '{print $1}'

if [[ -d /sdcard/Download ]]; then
  mkdir -p /sdcard/Download
  cp "$APK" /sdcard/Download/DeskSuite-release.apk
  printf 'Copied a convenience copy to /sdcard/Download/DeskSuite-release.apk\n'
fi
