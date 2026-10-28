#!/usr/bin/env bash
set -Eeuo pipefail

# Build DeskSuite with the owner's existing release key. Never creates, prints,
# uploads, or replaces a keystore. Optional --install requires a working ADB link.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! command -v flutter >/dev/null 2>&1; then
  echo "ERROR: Flutter is not on PATH. Install/use Flutter before building." >&2
  exit 2
fi
KEY_PROPERTIES="$ROOT/android/key.properties"
if [[ ! -f "$KEY_PROPERTIES" ]]; then
  cat >&2 <<'EOF'
ERROR: android/key.properties is missing.
DeskSuite will not silently use a new/debug signing identity for an update.
Copy android/key.properties.example to android/key.properties and fill it with
the path, alias, and passwords for your EXISTING keystore. Keep both files private.
EOF
  exit 3
fi
for property in storeFile keyAlias storePassword keyPassword; do
  if ! grep -Eq "^[[:space:]]*${property}[[:space:]]*=" "$KEY_PROPERTIES"; then
    echo "ERROR: android/key.properties is missing '$property'." >&2
    exit 3
  fi
done
if grep -Eiq 'CHANGE_ME|YOUR_.*(KEY|PASSWORD)|/path/to/.*\.jks' "$KEY_PROPERTIES"; then
  echo "ERROR: android/key.properties still contains example placeholders." >&2
  exit 3
fi

echo "==> Resolve dependencies"
flutter pub get
echo "==> Validate Android package and signing configuration"
flutter analyze
echo "==> Build signed release APK using the configured existing key"
flutter build apk --release

APK="$ROOT/build/app/outputs/flutter-apk/app-release.apk"
if [[ ! -s "$APK" ]]; then
  echo "ERROR: Flutter did not produce $APK" >&2
  exit 4
fi

APKSIGNER="$(command -v apksigner || true)"
if [[ -z "$APKSIGNER" && -n "${ANDROID_SDK_ROOT:-}" ]]; then
  APKSIGNER="$(find "$ANDROID_SDK_ROOT/build-tools" -type f -name apksigner 2>/dev/null | sort -V | tail -n 1 || true)"
fi
if [[ -z "$APKSIGNER" && -n "${ANDROID_HOME:-}" ]]; then
  APKSIGNER="$(find "$ANDROID_HOME/build-tools" -type f -name apksigner 2>/dev/null | sort -V | tail -n 1 || true)"
fi
if [[ -z "$APKSIGNER" ]]; then
  echo "APK built, but apksigner was not found. Install Android SDK build-tools to verify its signer." >&2
  echo "APK: $APK"
  exit 5
fi

SIGNER_OUTPUT="$("$APKSIGNER" verify --verbose --print-certs "$APK" 2>&1)" || {
  echo "ERROR: APK signature verification failed:" >&2
  printf '%s\n' "$SIGNER_OUTPUT" >&2
  exit 6
}
NEW_CERT="$(printf '%s\n' "$SIGNER_OUTPUT" | sed -nE 's/.*certificate SHA-256 digest: *([[:xdigit:]]+).*/\1/p' | head -n 1 | tr '[:upper:]' '[:lower:]')"
if [[ -z "$NEW_CERT" ]]; then
  echo "ERROR: APK signer certificate digest could not be read." >&2
  printf '%s\n' "$SIGNER_OUTPUT" >&2
  exit 6
fi
echo "Verified APK signer SHA-256: $NEW_CERT"
echo "APK: $APK"

if [[ "${1:-}" != "--install" ]]; then
  echo "Build and signature verification complete. No app was installed."
  echo "To compare the installed app's signer and install safely, enable Android Wireless debugging,"
  echo "connect ADB, then run: bash tools/android-build-phone.sh --install"
  echo "If you choose termux-open manually, Android will reject a mismatched signing key; do not uninstall the old app just to bypass that check."
  exit 0
fi

if ! command -v adb >/dev/null 2>&1; then
  echo "ERROR: --install requires adb on PATH. Enable Android Wireless debugging and connect first." >&2
  exit 7
fi
ADB_DEVICE="$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')"
if [[ -z "$ADB_DEVICE" ]]; then
  echo "ERROR: No authorized ADB device. Pair/connect with Android Wireless debugging first." >&2
  exit 7
fi

PACKAGE="com.zamcan.desksuite"
REMOTE="$(adb -s "$ADB_DEVICE" shell pm path "$PACKAGE" 2>/dev/null | tr -d '\r' | sed -n 's/^package://p' | head -n 1)"
if [[ -n "$REMOTE" ]]; then
  TMP_APK="$(mktemp "${TMPDIR:-/tmp}/desksuite-installed.XXXXXX.apk")"
  trap 'rm -f "${TMP_APK:-}"' EXIT
  if ! adb -s "$ADB_DEVICE" pull "$REMOTE" "$TMP_APK" >/dev/null; then
    echo "ERROR: Could not read the installed APK to compare signing identities. Nothing was installed." >&2
    exit 8
  fi
  OLD_OUTPUT="$("$APKSIGNER" verify --print-certs "$TMP_APK" 2>&1)" || {
    echo "ERROR: Could not verify the installed app's signer. Nothing was installed." >&2
    exit 8
  }
  OLD_CERT="$(printf '%s\n' "$OLD_OUTPUT" | sed -nE 's/.*certificate SHA-256 digest: *([[:xdigit:]]+).*/\1/p' | head -n 1 | tr '[:upper:]' '[:lower:]')"
  if [[ -z "$OLD_CERT" || "$OLD_CERT" != "$NEW_CERT" ]]; then
    echo "ERROR: Signing certificate differs from the installed app. Refusing to overwrite it." >&2
    echo "Installed certificate: ${OLD_CERT:-unavailable}" >&2
    echo "New APK certificate:   $NEW_CERT" >&2
    echo "Recover the original keystore; do not uninstall the existing app to bypass this check." >&2
    exit 9
  fi
  echo "Installed app signing certificate matches."
fi

adb -s "$ADB_DEVICE" install -r "$APK"
echo "DeskSuite installed/updated on $ADB_DEVICE."
