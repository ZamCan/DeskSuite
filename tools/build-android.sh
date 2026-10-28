#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail() { printf '\nDeskSuite build stopped: %s\n' "$1" >&2; exit 1; }

MODE="${1:-debug}"
INSTALL_MODE="${2:-}"
[[ "$MODE" == debug || "$MODE" == release ]] || fail "Use: bash tools/build-android.sh [debug|release] [--install]"
[[ -z "$INSTALL_MODE" || "$INSTALL_MODE" == --install ]] || fail "The only supported second argument is --install."
[[ "$INSTALL_MODE" != --install || "$MODE" == debug || "$MODE" == release ]] || fail "Invalid install mode."

command -v flutter >/dev/null 2>&1 || fail "Flutter is not on PATH; check your existing installation with flutter doctor -v."
command -v java >/dev/null 2>&1 || fail "Java is not on PATH; use a JDK compatible with the checked-in Gradle wrapper."
[[ -d android ]] || fail "The checked-in Android project is missing. Restore it from Git."

KEY_PROPERTIES="$ROOT/android/key.properties"
if [[ "$MODE" == release ]]; then
  [[ -s "$KEY_PROPERTIES" ]] || fail "A release requires android/key.properties and your existing private signing key. Copy android/key.properties.example to android/key.properties and fill it locally. Never commit the populated file or keystore."
  for property in storeFile keyAlias storePassword keyPassword; do
    grep -Eq "^[[:space:]]*${property}[[:space:]]*=" "$KEY_PROPERTIES" || fail "android/key.properties is missing '$property'."
  done
  if grep -Eiq 'CHANGE_ME|YOUR_.*(KEY|PASSWORD)|REPLACE_WITH|/path/to/.*\.jks' "$KEY_PROPERTIES"; then
    fail "android/key.properties still contains example placeholders."
  fi
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

APKSIGNER="$(command -v apksigner || true)"
if [[ -z "$APKSIGNER" && -n "${ANDROID_SDK_ROOT:-}" ]]; then
  APKSIGNER="$(find "$ANDROID_SDK_ROOT/build-tools" -type f -name apksigner 2>/dev/null | sort -V | tail -n 1 || true)"
fi
if [[ -z "$APKSIGNER" && -n "${ANDROID_HOME:-}" ]]; then
  APKSIGNER="$(find "$ANDROID_HOME/build-tools" -type f -name apksigner 2>/dev/null | sort -V | tail -n 1 || true)"
fi

NEW_CERT=""
if [[ "$MODE" == release || "$INSTALL_MODE" == --install ]]; then
  [[ -n "$APKSIGNER" ]] || fail "apksigner was not found. Install Android SDK build-tools before signing verification or installation."
  SIGNER_OUTPUT="$("$APKSIGNER" verify --verbose --print-certs "$APK" 2>&1)" || {
    printf 'ERROR: APK signature verification failed:\n%s\n' "$SIGNER_OUTPUT" >&2
    exit 6
  }
  NEW_CERT="$(printf '%s\n' "$SIGNER_OUTPUT" | sed -nE 's/.*certificate SHA-256 digest: *([[:xdigit:]]+).*/\1/p' | head -n 1 | tr '[:upper:]' '[:lower:]')"
  [[ -n "$NEW_CERT" ]] || {
    printf 'ERROR: APK signer certificate digest could not be read:\n%s\n' "$SIGNER_OUTPUT" >&2
    exit 6
  }
  printf 'Verified APK signer SHA-256: %s\n' "$NEW_CERT"
fi

if [[ -d /sdcard/Download && "$INSTALL_MODE" != --install ]]; then
  cp "$APK" "/sdcard/Download/DeskSuite-$MODE.apk"
  printf 'Copied to /sdcard/Download/DeskSuite-%s.apk\n' "$MODE"
fi

if [[ "$INSTALL_MODE" != --install ]]; then
  if [[ "$MODE" == debug ]]; then
    printf 'Debug-signed: for local testing only, not production distribution.\n'
  else
    printf 'Release signature verified. No app was installed.\n'
  fi
  printf 'To install safely after enabling Android Wireless debugging and connecting ADB, run: bash tools/build-android.sh %s --install\n' "$MODE"
  exit 0
fi

command -v adb >/dev/null 2>&1 || fail "--install requires adb on PATH. Enable Android Wireless debugging and connect first."
ADB_DEVICE="$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')"
[[ -n "$ADB_DEVICE" ]] || fail "No authorized ADB device. Pair/connect with Android Wireless debugging first."

PACKAGE="com.zamcan.desksuite"
REMOTE="$(adb -s "$ADB_DEVICE" shell pm path "$PACKAGE" 2>/dev/null | tr -d '\r' | sed -n 's/^package://p' | head -n 1 || true)"
if [[ -n "$REMOTE" ]]; then
  TMP_APK="$(mktemp "${TMPDIR:-/tmp}/desksuite-installed.XXXXXX")"
  trap 'rm -f "${TMP_APK:-}"' EXIT
  if ! adb -s "$ADB_DEVICE" pull "$REMOTE" "$TMP_APK" >/dev/null; then
    fail "Could not read the installed APK to compare signing identities. Nothing was installed."
  fi
  OLD_OUTPUT="$("$APKSIGNER" verify --print-certs "$TMP_APK" 2>&1)" || {
    printf 'ERROR: Could not verify the installed app signer:\n%s\n' "$OLD_OUTPUT" >&2
    exit 8
  }
  OLD_CERT="$(printf '%s\n' "$OLD_OUTPUT" | sed -nE 's/.*certificate SHA-256 digest: *([[:xdigit:]]+).*/\1/p' | head -n 1 | tr '[:upper:]' '[:lower:]')"
  if [[ -z "$OLD_CERT" || "$OLD_CERT" != "$NEW_CERT" ]]; then
    printf 'ERROR: Signing certificate differs from the installed app. Refusing to overwrite it.\nInstalled certificate: %s\nNew APK certificate:   %s\nRecover the original keystore; do not uninstall the existing app to bypass this check.\n' "${OLD_CERT:-unavailable}" "$NEW_CERT" >&2
    exit 9
  fi
  printf 'Installed app signing certificate matches.\n'
fi

adb -s "$ADB_DEVICE" install -r "$APK"
printf 'DeskSuite installed/updated on %s.\n' "$ADB_DEVICE"
