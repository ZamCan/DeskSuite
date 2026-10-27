# DeskSuite

**Create. Design. Print. Manage.**

DeskSuite is an Android-first, local-first Flutter workspace by ZamCan (Mussa Fikiri Ngwegelo). This repository is an actively developed foundation, **not a production-ready office suite**. The current document and image workflows have host-test evidence; native Android capture, storage, printing, signing and device behavior still need verification.

## What you can do in this source tree

- **Scan & assemble:** import PNG/JPEG/WebP or request an Android camera capture; manually correct page perspective; preview local uneven-lighting reduction or adaptive black-and-white and compare before/after. Rotate, apply grayscale or fixed-threshold B&W, reorder up to eight pages, reopen a draft, and export A4/US Letter **image-only PDFs** or PNG pages. The cleanup UI and native camera/providers need device testing.
- **Photo Studio:** first-frame PNG/JPEG/WebP input; rotate, flip, centre-square crop and resize; reduce isolated black/white specks on images up to 4 megapixels; zoom, compare and undo/reset; review dimensions and byte size before PNG/JPEG export. Speck reduction may soften detail and is not general restoration. JPEG flattens transparency to white. Photo sheets do not certify ID requirements.
- **Creative Studio:** editable physical-size designs with text, shapes and images; arrange, edit, undo/redo, autosave/reopen, import/export `.dsdesign`, export PNG or a flattened one-page PDF. Earlier `.dsproject` files can be imported as new copies without automatically changing the source.
- **Notes, Print and Business starter:** local plain-text notes and TXT export; A4 print-check PDF and OS print handoff; local products, opening stock, unit counter and JSON catalogue export. No accounting, payment or financial compliance claim.
- **Getting started and Conversion routes:** a skippable introduction, revisitable fictional sample tutorials that call the scan/photo/design engines, and an explicit catalogue of supported and unavailable routes. Try the deliberately shadowed field notes and noisy synthetic garden; see the [real pixel-engine before/after evidence](docs/engineering/cleanup-evidence.png).

Processing is local, without an account, paid API, analytics or cloud requirement. App-private data is **not encrypted by DeskSuite**; uninstalling or clearing data can remove it. Export and independently verify important copies. There is no complete backup/restore.

## Important limits

**No OCR, extracted text from arbitrary documents, searchable PDF, PDF reader/page editing, Office-format conversion, full document word processor, cloud sync or automatic edge detection is implemented.** Existing PDFs cannot be imported into the scanner. Native picker/camera/print access, process-death recovery, device accessibility, release signing and upgrades remain unverified. There is no claim of Acrobat, CamScanner, LibreOffice or Office parity.

Images are bounded to 8 MiB input, 12 megapixels and 8192 pixels per side; scan output has additional page, byte and pixel limits. External file providers can allow a user to overwrite an existing file: choose a **new destination**. See [user guide](docs/USER_GUIDE.md), [conversion registry](docs/CONVERSIONS.md), [file formats](docs/FILE_FORMATS.md) and [privacy](docs/PRIVACY_AND_SECURITY.md).

## Try the real workflows

1. Open **Getting started** from navigation. For cleanup, try the shadowed field notes or the noisy garden exercises; they call the same local processors as user files.
2. In **Scan & assemble**, choose **Try an example → Shadowed field notes → Clean up & compare**. Preview a method, switch **Before/After**, then apply only if satisfied. Export a separate PNG or prepare an image-only PDF; it is not searchable.
3. In **Photo Studio**, choose **Try a noisy garden photo → Reduce isolated specks**. Pinch to zoom and compare with the original. Undo or export a separate copy. **Resize** also supports fit-to-bounds or exact independent dimensions.
4. Open **Conversion routes** for supported operations and explicit unsupported routes. The new Flutter UI and native integrations still need the checks in the [validation record](docs/engineering/VALIDATION.md).

More detailed steps and recovery guidance: [user guide](docs/USER_GUIDE.md). Product-owner requirements: [master engineering directive](docs/engineering/MASTER_ENGINEERING_DIRECTIVE.md) and [additional instructions](docs/engineering/OWNER_INSTRUCTIONS.md). Engineering evidence: [current status](docs/engineering/CURRENT_STATUS.md), [baseline audit](docs/engineering/BASELINE_AUDIT.md), [engine evaluation](docs/engineering/ENGINE_EVALUATION.md), [validation record](docs/engineering/VALIDATION.md), [architecture](docs/ARCHITECTURE.md), [roadmap](docs/ROADMAP.md) and [changelog](CHANGELOG.md).

## Develop and build locally

Use your **existing** Flutter, JDK and Android SDK installations. Recorded host checks used Flutter 3.47.8 / Dart 3.13.7. Android's checked-in Gradle 9.3.1 needs a compatible JDK and Android SDK; no Android toolchain was installed for this work. Check out the branch or import the supplied Git bundle if it has not been pushed, then:

```sh
flutter pub get                     # use --offline when already cached
dart test/pixel_algorithms_smoke.dart # standalone pixel checks, no Flutter dependency
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub --concurrency=1 --reporter expanded --timeout 120s
bash tools/build-android.sh debug    # only with your existing Android toolchain
```

A debug APK is for local testing only. For release use a stable private key and local `android/key.properties`, then verify the actual APK/AAB signatures, app ID and behavior on devices. See [development and signing](docs/DEVELOPMENT.md) and [CI](docs/CI.md). **No current signed artifact or installation has been verified.**

The maintained Android application ID remains `com.zamcan.desksuite`. Older prototype builds with ID `com.zamcan.desksuite.desksuite` are separate installations with separate private data; different signing keys also prevent in-place updates. Export and verify backups before uninstalling or migrating.

Repository code: [Apache-2.0](LICENSE). Dependency and sample attribution: [third-party notices](THIRD_PARTY_NOTICES.md). Android native/transitive binary licences must still be reviewed for the actual release.
