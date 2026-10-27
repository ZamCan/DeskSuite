#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
fail() { printf '\nDeskSuite build stopped: %s\n' "$1" >&2; exit 1; }

MODE="${1:-debug}"
[[ "$MODE" == debug || "$MODE" == release ]] || fail "Use: bash tools/build-android.sh [debug|release]"
command -v flutter >/dev/null 2>&1 || fail "Flutter is not on PATH; check your existing installation with flutter doctor -v."
command -v java >/dev/null 2>&1 || fail "Java is not on PATH; use a JDK compatible with the checked-in Gradle wrapper."
[[ -d android ]] || fail "The checked-in Android project is missing. Restore it from Git."
if [[ "$MODE" == release && ! -s android/key.properties ]]; then
  fail "A release requires local android/key.properties and a private signing key. See docs/DEVELOPMENT.md; never commit signing credentials. For a test build use: bash tools/build-android.sh debug"
fi

printf '\n== DeskSuite Android %s build ==\nRepository: %s\n' "$MODE" "$ROOT"
flutter --version
java -version
printf '\n== Dependency resolution ==\n'
flutter pub get
printf '\n== Formatting check ==\n'
dart format --output=none --set-exit-if-changed lib test
printf '\n== Static analysis ==\n'
flutter analyze --no-pub
printf '\n== Host tests ==\n'
flutter test --no-pub --concurrency=1
printf '\n== Android APK (%s) ==\n' "$MODE"
flutter build apk "--$MODE"
APK="$ROOT/build/app/outputs/flutter-apk/app-$MODE.apk"
[[ -s "$APK" ]] || fail "Flutter did not produce the expected APK: $APK"
printf '\nAPK: %s\n' "$APK"
if [[ "$MODE" == debug ]]; then
  printf 'Debug-signed: for local testing only, not production distribution.\n'
else
  printf 'Verify the APK signature, package ID, device behavior and release gates before distribution.\n'
fi
if [[ -d /sdcard/Download ]]; then
  cp "$APK" "/sdcard/Download/DeskSuite-$MODE.apk"
  printf 'Copied to /sdcard/Download/DeskSuite-%s.apk\n' "$MODE"
fi
