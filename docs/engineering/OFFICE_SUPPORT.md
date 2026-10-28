# Office documents: implementation and validation

Updated 2026-10-28. This is a source/host-test record, **not** a claim that
all Office documents render faithfully or that the Android preview has passed
a device, security or release test.

## Stable and experimental paths

| Path | Availability | What it actually does |
| --- | --- | --- |
| Dart office reader | Normal build | Extracts readable DOCX/XLSX/PPTX/ODT/ODS/ODP/RTF content, not the original page layout. |
| Dart content editor and writers | Normal build | Edits extracted paragraphs/cells and makes real but simplified DOCX/XLSX/ODT/ODS/PDF/TXT/CSV copies. Unsupported styling, images, charts, macros and layout may be lost. |
| OpenDocument.core 7.6.1 preview | **Experimental, Android-only, disabled by default** | A C++ Office rendering engine compiled to WebAssembly generates HTML inside a background worker. The Android platform view displays it read-only in an isolated WebView frame. It is not a conversion/export engine or a web-app shell. The Android implementation has **not** been run on a device in this workspace. |
| `ExternalOfficeEngine` | Interface only; default `NoExternalOfficeEngine` | No executable detection, LibreOffice/soffice adapter, Termux configuration or full-layout conversion is implemented. |

An experimental build can be tested locally with an existing Android toolchain:

```sh
flutter run --dart-define=DESKSUITE_EXPERIMENTAL_OFFICE_PREVIEW=true
```

Choose a document in **Document converter**, then select **Preview original
layout (experimental)**. This does not enable legacy editing, saving the view,
printing it, or rendered conversion. Files over 8 MiB are refused by this
preview. A default build keeps the feature disabled until the device/security
gates below are satisfied; the renderer assets still increase the Android
source/package size even when disabled. The user packages the app locally; no
Android toolchain was downloaded or app packaged for this change.

LibreOffice **can** be embedded on Android: the official LibreOffice Android
viewer uses native LibreOffice code/JNI. This repository does not integrate it.
The earlier claims that embedding it is impossible, that a Termux package is
configured, or that DeskSuite detects `soffice` were incorrect and have been
removed. Other real Android/native engines exist; a library's documented format
support is not evidence that DeskSuite's integration works.

## Format matrix

| Input | Normal build: readable content / conversion | Experimental renderer, host evidence |
| --- | --- | --- |
| DOCX | Content; PDF/TXT/ODT | One real upstream fixture generated HTML with its expected text. |
| XLSX | Content; PDF/CSV/ODS | One real fixture generated a sheet view with expected cell text. |
| PPTX | Slide text; PDF/TXT/ODT | One real fixture yielded eight slide views; first view contained expected text. |
| DOC | No built-in content conversion | One real fixture generated HTML with expected text. |
| XLS | No built-in content conversion | One real fixture generated a sheet view with expected cell text. |
| PPT | No built-in content conversion | One real fixture yielded eight slide views; first view contained expected text. |
| ODT/ODS/ODP | Content; PDF and appropriate text/CSV/ODF copies | One fixture of each generated HTML with expected text under Node; Android remains untested. |
| RTF, TXT, HTML | Content-level routes where offered | Not offered by this preview. |
| PDF | No existing-PDF import or manipulation in this path | Not offered by this preview. |

The six Office results are **one fixture per format**, checked for engine
output and recognizable text under Node. They do not establish visual
fidelity, editability, Android WebView behavior, support for arbitrary
files, chart/formula accuracy, RTL shaping or Microsoft Office parity. Legacy
binary support upstream is limited; complex layout may differ or be omitted.
Password-protected documents are not supported by the preview. The OLE2
signature is shared: a `.doc`/`.xls`/`.ppt` filename is only a subtype hint,
not proof. An unknown OLE2 subtype remains unconfirmed until the renderer
examines it.

## Experimental design and safeguards

- Engine: pinned npm `@opendocument/odr-core` **7.6.1**, upstream release
  commit `4a1ce6e505a325147f6d3360d29625aa432a669a`. `index.js` and
  `odr-core.mjs` are upstream artifacts. The 5,995,126-byte upstream WASM
  (`ec17dc0b81bb8bb8f3224bfe364fbc0879f15818f938119bc06121b15c206c9d`)
  has its one memory-section maximum changed from 4 GiB to 256 MiB by
  `tools/patch_odr_wasm_memory.py`. Result: 5,995,125 bytes, SHA-256
  `4801d59d42ddf95e7d7ccfae104f5943e2242e9630c458bddd416c31ad48aaca`.
  Node validated the module and demonstrated that growth beyond the maximum
  throws. **256 MiB is only the WASM linear-memory cap**: JS, HTML, document
  bytes, DOM, WebView and app memory are additional, so total RAM is not capped.
- Each preview is a native Android platform view, separate from the Flutter app
  shell. The host reads only an exact local virtual-origin allowlist from APK
  assets and in-memory document bytes. It attempts to block all network loads,
  file/content access, navigation, permissions and storage; no JavaScript
  interface is added. Trusted host/worker JavaScript is enabled; rendered
  document HTML is put into a `sandbox` iframe without scripts, same-origin,
  forms, popups or top navigation. A restrictive CSP and disabled external
  document resources provide additional layers. These are **design controls,
  not yet a proven Android security boundary**. Test WebView versions,
  `blockNetworkLoads` versus interception, CSP/iframe inheritance, service
  workers, external URLs, file access, malicious documents and network traffic
  before enabling by default.
- Source limit 8 MiB; at most 100 views; 5,000 spreadsheet rows, 200 columns
  and 50,000 cells per sheet; a rendered view is refused above 8,388,608 HTML
  characters. The UI warns when the engine reports a cut or missing media.
  A worker is terminated after 20 seconds per open/render operation when the
  hosting page can run its timer. This is not a hard OS CPU or total-memory
  limit; malicious or complex documents still need device stress testing.
- Rendered HTML is read-only; script-dependent layout/interaction, linked
  media, fonts and unsupported elements can be missing or differ. The original
  buffer is never written by the preview.

## ZIP package safeguards

`office_zip_guard.dart` checks a single-disk ZIP's end record, central directory,
local headers, entry count/sizes, overlaps and names **before** `ZipDecoder`
can inflate Unix symlinks. It rejects symlinks, encryption, duplicate entries,
ZIP64, non-store/non-deflate entries, inconsistent headers and overlaps. This
is intentionally narrower than general ZIP and can reject otherwise valid
unusual Office files. `OfficePackage` verifies each expanded size and CRC
explicitly: the pinned archive 4.5.2 `verify` parameter does not perform CRC
verification. The archive decoder's per-entry output is bounded by the stated
uncompressed size after the preflight.

| Bound | Value |
| --- | --- |
| Compressed Office package | 48 MiB |
| One uncompressed part | 24 MiB |
| Total declared expanded parts | 64 MiB |
| Entries | 4,000 |

A valid synthetic ZIP, truncations and 3,000 byte mutations passed the pure
Dart guard smoke under DartPad DDC/Node. Three real upstream DOCX/XLSX/PPTX
fixtures passed the guard there. New Flutter package/CRC tests were written,
but have not been run with the real Dart archive package in this workspace;
these checks are not a complete security audit.

## Host test reproduction

`node tools/test_office_renderer.mjs` validates the pinned WASM hash, checks
its memory maximum and invalid input, and renders the four fictional, locally
bundled DOCX/XLSX/PPTX/XLS fixtures (including second sheets/slides). For the
additional upstream fixtures, supply a directory containing these files from
[OpenDocument.test at its pinned test-data revision](https://github.com/opendocument-app/OpenDocument.test/tree/2a69662064eee0b4fb368bf99a875d77ee4e74b1):
`doc/11KB.doc`, `docx/11KB.docx`, `xls/file_example_XLS_10.xls`,
`xlsx/file_example_XLSX_10.xlsx`, `ppt/style-various-1.ppt`,
`pptx/style-various-1.pptx`, `odt/mixed-layout.odt`,
`ods/file_example_ODS_10.ods`, `odp/style-various-1.odp`; also add
`wasm/testfixtures/encrypted.docx` from
[OpenDocument.core v7.6.1](https://github.com/opendocument-app/OpenDocument.core/tree/v7.6.1).
The fixture directory is for local testing; the upstream test repository does
not state a redistribution licence, so these fixtures are not bundled here.

```sh
node tools/test_office_renderer.mjs /path/to/fixtures
node tools/test_office_viewer_ui.mjs
mkdir -p /tmp/desksuite-office-policy
javac -d /tmp/desksuite-office-policy \
  android/app/src/main/java/com/zamcan/desksuite/OfficePreviewPolicy.java \
  tools/OfficePreviewPolicyTest.java
java -cp /tmp/desksuite-office-policy com.zamcan.desksuite.OfficePreviewPolicyTest
flutter test --no-pub test/office_engine_test.dart test/office_package_guard_test.dart test/office_preview_page_test.dart
```

The worker and nine-format smoke, invalid/encrypted-input checks, WASM memory
growth check, Java request-allowlist test and a fake-DOM control test passed
in the host environment. A Java syntax/type check used hand-written Android/
Flutter stubs; it was **not** an Android build. The pure-Dart preflight and
Flutter launch/preview source were analyzed with DartPad. Flutter widget and
real archive-codec tests remain unrun.

## Required before enabling or distributing a release

1. Build with existing Flutter/JDK/Android tools; run analyzer, complete Flutter
   suite and Android instrumentation. Test current and minimum supported Android
   System WebView versions in airplane mode, with a network monitor and hostile
   document URLs; prove requests do not leave the device and that the virtual
   origin/worker/iframe load while `blockNetworkLoads` is on.
2. Compare visual output against known-good viewers on representative DOC,
   DOCX, XLS, XLSX, PPT, PPTX and ODF files: multipage, many sheets/slides,
   images, charts, fonts, formulas, RTL, large and corrupted inputs. Test
   cut/error messages, lifecycle, cancellation, accessibility, crashes and RAM
   on low-memory devices. Measure APK/AAB size and ABI/API coverage.
3. Complete the actual bundled native/binary and transitive-licence audit,
   include all notices and required corresponding sources in distribution, and
   verify the released archive's contents. See [third-party notices](../../THIRD_PARTY_NOTICES.md)
   and `third_party/odr-source/`. Do not claim licence review complete merely
   because upstream licences have been collected.
4. Keep full-layout conversion and editing unavailable until separately
   implemented and independently verified. A rendered HTML preview is not PDF
   conversion and does not establish round-trip editing fidelity.
