# Development and local builds

## Prerequisites

Use your existing compatible Flutter SDK, Git, and platform toolchain. Host checks here used Flutter 3.47.8 / Dart 3.13.7. `pubspec.yaml` declares Dart >=3.13 and Flutter >=3.47; the lockfile must also resolve. Android's checked-in Gradle 9.3.1 needs a compatible JDK (JDK 21 is a sensible choice) and an installed Android SDK. Validate with `flutter doctor -v`. Termux/Debian compatibility depends on your actual SDK, JVM and native binaries; diagnose failures locally rather than downloading duplicate toolchains blindly.

```sh
flutter pub get  # may need network the first time; use --offline if dependencies are cached
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub --concurrency=1 --reporter expanded --timeout 120s
```

Sequential tests avoid high peak memory on smaller systems. The exact prior baseline and targeted runs are recorded in [engineering/VALIDATION.md](engineering/VALIDATION.md); native plugin calls in host tests use fakes. The complete suite after all document changes, physical devices and the current APK/AAB remain unverified.

## Android: debug, release and signing

`android/` is checked in and has application ID `com.zamcan.desksuite`. Do not rerun `flutter create` for normal Android builds. The script can be invoked from any directory:

```sh
bash tools/build-android.sh debug
# Or, after setting up private release signing:
bash tools/build-android.sh release
# Optional AAB after the same signing setup:
flutter build appbundle --release
```

The script resolves declared Dart dependencies, checks formatting and analysis, runs host tests, builds one APK, and optionally copies it to `/sdcard/Download` when that directory exists. The debug APK uses the local debug key and is **for testing only**. The script requires a nonempty `android/key.properties` for its release mode. Direct Gradle/Flutter release builds without signing configuration can be unsigned or fail; do not treat either as a distributable release.

For release signing, follow Flutter/Android's signing documentation using your own existing keystore. Keep the key and `android/key.properties` outside version control. The checked-in Gradle configuration reads these keys (use an absolute `storeFile` path):

```properties
storeFile=/absolute/path/to/private-keystore.jks
storePassword=YOUR_PRIVATE_VALUE
keyAlias=YOUR_ALIAS
keyPassword=YOUR_PRIVATE_VALUE
```

Do not paste real values into source, logs or chat. Back up the key securely; the same package ID **and** compatible signing identity are needed for in-place updates. Inspect the actual output and run the SDK's `apksigner verify --verbose --print-certs` against the APK; check AAB signing as appropriate. Verify version, install/upgrade, file access, offline workflows and printing on real devices before distributing.

Current main and the earlier creative APK use `com.zamcan.desksuite`; the pre-merge prototype generator command (`--org com.zamcan.desksuite` plus project `desksuite`) yields `com.zamcan.desksuite.desksuite`, a separate installation. No cross-ID automatic private-data migration exists. Export/reimport copies while the old app is still installed, where that old version permits it.

## Desktop / iOS exploration

Windows and Linux do not yet have checked-in platform runners here. Before generating them, commit or back up your work and lockfile; Flutter's generator in this environment rewrote `pubspec.lock` even with `--no-pub`. Restore the intended lockfile, inspect `git diff`, then resolve dependencies. Example **on an appropriate host**:

```sh
cp pubspec.lock pubspec.lock.before-platform-create
flutter create --no-pub --project-name desksuite --org com.zamcan.desksuite --platforms=linux,windows .
cp pubspec.lock.before-platform-create pubspec.lock && rm pubspec.lock.before-platform-create
flutter pub get
flutter build linux --release      # Linux desktop dependencies required
# On Windows with Visual Studio C++ tooling instead:
flutter build windows --release
```

These are instructions, not reported build results. Windows bundles need their runtime files; an AppImage requires additional packaging and testing. iOS requires macOS/Xcode and Apple provisioning; no iOS build was performed. Plugins and app-private storage must be validated per platform.
