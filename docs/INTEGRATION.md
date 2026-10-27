# Reconciled branch integration

## Integration record — 2026-10-27

This integration is based on current `main` and incorporates the modular creative-studio branch `agent/creative-studio-android` without force-pushing or deleting either source branch.

### Selected as the active implementation

- Modular Flutter entry point and theme.
- Structured design document, geometry, editor controller, renderer and editor widgets.
- Local project repository and file gateway.
- Bounded PNG/PDF export engine.
- The creative-studio branch's automated tests, Android Gradle runner, dependency lockfile and third-party notices.

### Preserved from the prior main branch

- Existing Android/Windows/Linux/iOS GitHub Actions workflow and Termux build script, adapted to the modular app.
- The former single-file prototype is preserved as `docs/archive/main-prototype.dart.txt`. It is a source archive only, not compiled into the active app.
- Existing repository documentation not replaced by the newer modular architecture documentation.

### Why this is a proportional merge

The two branches had diverged: the creative branch was four commits ahead and fifteen behind `main`, with overlapping but different app entry points, dependency manifests, tests and docs. Blindly selecting either complete tree would have discarded work. The reconciled tree therefore adopts the better-tested modular editor as the active app, preserves the previous prototype source, keeps the current build workflow and script, and explicitly tracks the prototype tools as migration work.

### Build/toolchain note

The app uses Flutter/Dart. The Android runner is Gradle-based, but **Gradle alone cannot compile Flutter/Dart source**. When Flutter is unavailable in Termux, use GitHub Actions to build and download a validation artifact; local Gradle commands are not a substitute for Flutter's build step.

### Next verification gates

1. Confirm the Android CI job completes `flutter pub get`, `flutter analyze`, all tests, APK and AAB builds.
2. Review Windows/Linux/iOS CI jobs individually; an unsigned iOS validation bundle is not a signed IPA.
3. Test the APK on an actual Android device in airplane mode, then verify import/export and print-dialog behaviour.
4. Port Photo, Notes, Print and Business prototypes into separate modules with tests and explicit local-data migration.
5. Configure and test a persistent release-signing key before promising install-over updates or publishing.
6. Only then consider moving the integration into `main`; do not force-push either source branch.
