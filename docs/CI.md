# Continuous integration and release builds

> **Owner policy / current consolidation:** the active `main` push/PR workflow below downloads toolchains and packages Android and desktop builds. The owner wants to run packaging locally using existing tools. Do not trigger this workflow or change CI policy without resolving that conflict. An intentional `[skip ci]` would skip validation too and may leave required checks pending; it is not a test pass. For an existing installation, retain the existing signing key—do not generate or upload a replacement key merely because the historical example below describes one.


## Two files, one reason

The **active** workflow is [`.github/workflows/build.yml`](../.github/workflows/build.yml):
it runs format, analysis and the host suite, then builds Android, Windows, Linux
and unsigned iOS validation artifacts. It does **not** sign releases.

The improved pipeline lives at
[`ci/android-testing-and-release.yml.example`](../ci/android-testing-and-release.yml.example)
and is **not active**. It could not be installed by the agent that wrote it: the
GitHub token in use has no `workflow` scope, and GitHub rejects any push that
touches `.github/workflows/` without it (`refusing to allow a Personal Access
Token to create or update workflow ... without workflow scope`). This is the same
restriction recorded in earlier work on this repository.

**To activate it**, a maintainer with `workflow` scope (or the GitHub web editor)
must replace `.github/workflows/build.yml` with that file. Its Android job does
everything below. Until then, treat the current `build.yml` as validation only
and do not distribute its release output.

## The proposed `android` job (in the example file)

## What each job does

### `android` — Android testing and release

1. `flutter pub get`
2. `dart format --output=none --set-exit-if-changed lib test` — **checks**, it
   does not rewrite the tree.
3. `flutter analyze`
4. `dart test/pixel_algorithms_smoke.dart` — the standalone pixel-engine check.
5. `flutter test --concurrency=1` — the full host suite.
6. `flutter build apk --debug` — always produced. This APK is debug-signed and
   installable for testing; it is never a distribution artifact.
7. Release build, signed **only when the repository secrets below exist**:
   - the keystore is decoded into `$RUNNER_TEMP` (outside the repository), and
     `android/key.properties` is written from secrets for the duration of the
     job;
   - `flutter build apk --release` and `flutter build appbundle --release`;
   - `apksigner verify --print-certs` must succeed, and every expected artifact
     must be non-empty.
8. Without secrets the same release commands run but the artifacts are uploaded
   under `desksuite-android-release-unsigned`, with a workflow warning. An
   unsigned artifact must not be distributed.

Artifacts: `desksuite-android-debug`, plus either
`desksuite-android-release-signed` or `desksuite-android-release-unsigned`.

### `windows`, `linux`, `ios`

Validation jobs. They generate their own platform runners with
`flutter create`, restore `test/widget_test.dart`, run the same format check,
analysis and host tests, then build. iOS is unsigned: it validates compilation
only and is not a store-ready IPA. The Linux job also packages a tarball and an
AppImage.

## Release signing

**Never commit a keystore, `key.properties`, or any password to the repository.**
`android/app/build.gradle.kts` reads `android/key.properties` only when that file
exists; there is no debug-key fallback for release builds.

Create the key once, on a trusted machine (JDK `keytool`):

```bash
keytool -genkeypair -v \
  -keystore desksuite-release.jks \
  -alias desksuite \
  -keyalg RSA -keysize 4096 -validity 10000 \
  -dname "CN=DeskSuite, O=ZamCan, C=TZ"
```

Then encode it for the secret:

```bash
base64 -w0 desksuite-release.jks > desksuite-release.jks.b64
```

Add these **repository secrets** (Settings → Secrets and variables → Actions):

| Secret | Contents |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | base64 of `desksuite-release.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | the store password |
| `ANDROID_KEY_ALIAS` | the key alias, e.g. `desksuite` |
| `ANDROID_KEY_PASSWORD` | the key password |

Keep an offline backup of the keystore and its passwords. **Losing them means
future builds cannot update an installed app**: Android rejects an update signed
with a different key. Every release must use the same identity, which is why the
workflow reads one fixed keystore from secrets and never generates a key.

If the keystore exists and CI builds have already shipped with a different
identity, that mismatch must be resolved deliberately (the app ID would have to
change) rather than silently.

## Offline / Termux builds

`tools/build-android.sh` runs the same gates locally (format check, analysis,
full host suite) and then builds an APK. A release build from the script requires
`android/key.properties` with `storeFile`, `storePassword`, `keyAlias` and
`keyPassword` pointing at a keystore outside version control:

```bash
bash tools/build-android.sh debug   # installable, debug-signed
bash tools/build-android.sh release # requires android/key.properties
```

## What CI does not prove

A green workflow proves that the Dart code formats, analyses, passes host tests,
and that the Android/native/desktop toolchains compile the project. It does **not**
prove:

- camera capture, file pickers, sharing or printing on a real device;
- OCR accuracy or scanner quality on photographs;
- memory, battery or frame performance on a phone;
- that LibreOffice-driven conversions work.

Record those results from a real installation, not from CI.

## Known build-size notes

The APK carries native OCR libraries per ABI and two language models
(≈6.3 MB of tessdata) plus a subsettable font. App Bundles let Play deliver only
the matching ABI; a universal direct APK is larger. Measure the actual artifacts
rather than estimating.
