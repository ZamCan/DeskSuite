# Integration history

The following earlier record is historical; the later integration below restores live prototype modules.

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


## Subsequent unified-studios integration — 2026-10-27

After the above merge, `main` advanced to `b2d22cb`. This branch starts from that exact commit, preserving its modular workspace, Files & Projects, dark setting, Android application ID `com.zamcan.desksuite`, and active CI workflow. It restores the archived prototype's Photo, Notes, Print, Business and earlier editor as actual navigation destinations, with bounded processing, persistence/error handling and host tests. Other restored studios use light surfaces even when the current workspace is dark.

Main's current editable project root is `getApplicationDocumentsDirectory()/DeskSuite`; it remains the active root. Earlier prototype notes, products and `.dsproject` files use `getApplicationSupportDirectory()/desksuite`. The design browser discovers earlier files under that support root **within the same installation** and imports a new copy into the current root, leaving the source unchanged. Existing current designs and theme settings remain in place.

An older pre-merge prototype created from `--org com.zamcan.desksuite` and project name `desksuite` would use `com.zamcan.desksuite.desksuite`, whereas current main and the experimental creative APK use `com.zamcan.desksuite`. Different Android IDs have isolated private data; different signing keys also block in-place updates. Export and verify user-accessible backups before replacing or uninstalling anything. Some old prototypes have no editable export button; preserve their installations and use an appropriate verified device backup or authorized debug-access method rather than assuming recovery. No cross-ID migration is implemented.

The existing CI workflow is unmodified. Local host checks passed; no integrated APK/AAB, GitHub Actions run, actual printer or device upgrade is claimed.
