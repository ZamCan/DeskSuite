# Development and release

## Toolchain

- Flutter 3.47.8 / Dart 3.13.7 (stable release tag).
- JDK 21; Android SDK platform 36 and build-tools 36.0.0; SDK licences accepted.
- Android min API 24; app ID `com.zamcan.desksuite`.
- The Android Gradle wrapper is checked in. Its Gradle 9.3.1 distribution has a SHA-256 checksum in `android/gradle/wrapper/gradle-wrapper.properties`.
- `pubspec.lock` pins resolved dependencies. No keys, SDK paths, tokens or signing configuration belong in Git.

Set `JAVA_HOME`, `ANDROID_HOME` and `PATH` according to your local SDK installation, then:

```sh
flutter doctor -v
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test --reporter expanded
flutter build apk --debug
```

If an Android SDK component is missing, install it using Android Studio or `sdkmanager`; accept licences with `flutter doctor --android-licenses`. Gradle may request an NDK during the first build. Debug builds need Android's `INTERNET` permission for Flutter tooling; this app has no implemented network service.

The final debug build was also run specifically for 64-bit ARM:

```sh
flutter build apk --debug --target-platform=android-arm64 --split-per-abi --no-pub --android-project-arg=kotlin.compiler.execution.strategy=in-process
```

`build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk` was produced and verified with `apksigner`; it targets API 24+ and only the arm64 ABI. Install only after connecting a compatible device: `adb devices`, then `adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk`. Installation and operation have not been verified because no Android device/emulator was attached. The temporary debug keystore is not part of the repository; a different signing key cannot update this install. Export projects before any uninstall.

For a release, configure a real release keystore and signing process outside this repository, review third-party licences and permissions, run device/airplane-mode/print tests, and create a reproducible release pipeline. Release signing is intentionally not configured; the debug key must not be used as a production identity.

## Tests and constraints

Tests under `test/` cover domain history and geometry, project files and failure cases, raster/PDF rendering, a network-blocked core workflow, and a phone-sized widget workflow with fake platform pickers. They do not simulate every native Android plugin, hardware printer or actual app installation.

On memory-limited hosts, stop competing builds/tests and reduce Gradle concurrency. This repository sets one worker, a 768 MB Java heap and in-process Kotlin compilation. In the supplied 2 GB environment, two builds were killed by the host out-of-memory killer, and a smaller metaspace then caused a D8 metaspace error. Running without concurrent tests, using swap and increasing metaspace were the targeted mitigations; do not assume an unexplained daemon exit is a compiler error.
