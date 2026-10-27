# DeskSuite

**Create. Design. Print. Manage.**

DeskSuite is an Android-first, local-first Flutter workspace by ZamCan (Mussa Fikiri Ngwegelo). This repository is an actively developed foundation, **not a production-ready office suite**. The current document and image workflows have host-test evidence; native Android capture, storage, printing, signing and device behavior still need verification.

## What you can do in this source tree

- **Scan & assemble:** import PNG/JPEG/WebP or request an Android camera capture; manually adjust four page corners with true projective correction, choose known paper proportions, rotate and apply grayscale or fixed-threshold black-and-white. Reorder up to eight pages, reopen a local draft, and export ordered A4/US Letter **image-only PDFs** or individual PNG pages. Camera and file providers are not yet device-tested.
- **Photo Studio:** first-frame PNG/JPEG/WebP input; rotate, flip, centre-square crop, fit-to-bounds or exact independent pixel resize; compare, undo/reset; review actual dimensions and byte size before PNG/JPEG export. JPEG flattens transparency to white. Optional repeated-photo sheet PDF/print handoff does not certify ID requirements.
- **Creative Studio:** editable physical-size designs with text, shapes and images; arrange, edit, undo/redo, autosave/reopen, import/export `.dsdesign`, export PNG or a flattened one-page PDF. Earlier `.dsproject` files can be imported as new copies without automatically changing the source.
- **Notes, Print and Business starter:** local plain-text notes and TXT export; A4 print-check PDF and OS print handoff; local products, opening stock, unit counter and JSON catalogue export. No accounting, payment or financial compliance claim.
- **Getting started and Conversion routes:** a skippable introduction, revisitable fictional sample tutorials that call the real scan/photo/design engines, and an explicit catalogue of supported and unavailable routes. Bundled forms and names are fictional; the practice photo is synthetic.

Processing is local, without an account, paid API, analytics or cloud requirement. App-private data is **not encrypted by DeskSuite**; uninstalling or clearing data can remove it. Export and independently verify important copies. There is no complete backup/restore.

## Important limits

**No OCR, extracted text from arbitrary documents, searchable PDF, PDF reader/page editing, Office-format conversion, full document word processor, cloud sync or automatic edge detection is implemented.** Existing PDFs cannot be imported into the scanner. Native picker/camera/print access, process-death recovery, device accessibility, release signing and upgrades remain unverified. There is no claim of Acrobat, CamScanner, LibreOffice or Office parity.

Images are bounded to 8 MiB input, 12 megapixels and 8192 pixels per side; scan output has additional page, byte and pixel limits. External file providers can allow a user to overwrite an existing file: choose a **new destination**. See [user guide](docs/USER_GUIDE.md), [conversion registry](docs/CONVERSIONS.md), [file formats](docs/FILE_FORMATS.md) and [privacy](docs/PRIVACY_AND_SECURITY.md).

## Try the real workflows

1. Open **Getting started** from navigation; choose the two-page report, perspective letter or synthetic photo exercise. The examples use the same processors as user files.
2. In **Scan & assemble**, add images, select known page proportions if appropriate, use **Corners & correct**, reorder, then **Prepare PDF**. Save a copy and verify it in an external reader. This PDF is not searchable.
3. In **Photo Studio**, choose an image and **Resize**. Keep aspect ratio to fit, or turn it off to force exact width and height. Export PNG/JPG, review actual encoded size, then save a copy.
4. Open **Conversion routes** for supported operations and explicit unsupported routes.

More detailed steps and recovery guidance: [user guide](docs/USER_GUIDE.md). Engineering evidence: [baseline audit](docs/engineering/BASELINE_AUDIT.md), [engine evaluation](docs/engineering/ENGINE_EVALUATION.md), [validation record](docs/engineering/VALIDATION.md), [architecture](docs/ARCHITECTURE.md), [roadmap](docs/ROADMAP.md) and [changelog](CHANGELOG.md).

## Develop and build locally

Use your **existing** Flutter, JDK and Android SDK installations. Recorded host checks used Flutter 3.47.8 / Dart 3.13.7. Android's checked-in Gradle 9.3.1 needs a compatible JDK and Android SDK; no Android toolchain was installed for this work. Check out the branch or import the supplied Git bundle if it has not been pushed, then:

```sh
flutter pub get                     # use --offline when already cached
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub --concurrency=1 --reporter expanded --timeout 120s
bash tools/build-android.sh debug    # only with your existing Android toolchain
```

A debug APK is for local testing only. For release use a stable private key and local `android/key.properties`, then verify the actual APK/AAB signatures, app ID and behavior on devices. See [development and signing](docs/DEVELOPMENT.md) and [CI](docs/CI.md). **No current signed artifact or installation has been verified.**

The maintained Android application ID remains `com.zamcan.desksuite`. Older prototype builds with ID `com.zamcan.desksuite.desksuite` are separate installations with separate private data; different signing keys also prevent in-place updates. Export and verify backups before uninstalling or migrating.

Repository code: [Apache-2.0](LICENSE). Dependency and sample attribution: [third-party notices](THIRD_PARTY_NOTICES.md). Android native/transitive binary licences must still be reviewed for the actual release.
