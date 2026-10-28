# Office documents: implementation and boundaries

Recorded 2026-10-28 for the selective consolidation. This is source status and limited host evidence, **not** a claim of full Office compatibility or an Android device pass. See [validation](VALIDATION.md) and [template samples](TEMPLATE_SAMPLE_PACKS.md).

## Three distinct paths

1. **Built-in content reader/editor and writers** (`lib/office/`): bounded local ZIP/XML reading of DOCX, XLSX, PPTX and ODF plus RTF, with content-level PDF/TXT/CSV/ODT/ODS conversions and selected edited DOCX/XLSX exports. Text, selected headings/tables and sheet values can be retained; original layout, images, charts, macros, exact fonts and spreadsheet formulas/styles are not reliably retained. Cached formula values are displayed where available; formulas are not calculated. Edited PPTX export is unavailable.
2. **Six fictional original templates**: two DOCX, two XLSX and two PPTX files can be saved byte-for-byte unchanged for editing in a compatible application. That is not an in-app Office round trip. Choose a distinct save destination and verify compatibility.
3. **Experimental original-layout preview**: the bundled OpenDocument.core 7.6.1 C++ engine compiled to WebAssembly runs inside a restricted local Android WebView. It is read-only, disabled by default, and enabled only in a test build with `--dart-define=DESKSUITE_EXPERIMENTAL_OFFICE_PREVIEW=true`. It can attempt OOXML/ODF and legacy OLE documents within its limits. It is not a conversion engine, editing engine or fidelity guarantee; Android isolation, accessibility and real documents are not yet verified. Standard builds do not offer legacy DOC/XLS/PPT conversion.

`ExternalOfficeEngine` is only a capability seam. No executable discovery, Termux integration or LibreOffice adapter is configured. Installing a separate office application does not automatically make DeskSuite conversions available. LibreOffice does have Android integration approaches upstream, but it is not bundled here; embedding one would need substantial native work, platform, licensing and resource review.

## Safety limits and provenance

- Package reader: 48 MiB compressed input, 24 MiB per part, 64 MiB total expanded data and 4,000 entries; central-directory preflight rejects malformed/overlapping ZIP data, ZIP64, encrypted packages, duplicates and symlinks. Inflated entries receive size and CRC checks. Limits reduce risk; they are not a guarantee against all malicious files or device memory exhaustion. The same validated package is reused during each content read rather than inflated twice.
- Preview: at most 8 MiB source, a 20-second worker limit, at most 8,388,608 HTML characters and 50,000 spreadsheet cells; the modified WASM linear-memory maximum is 256 MiB, excluding WebView/DOM memory. Network loads are blocked and local requests are allowlisted in source, but actual WebView interception and isolation must be tested on supported Android versions.
- `third_party/odr-source/README.md` records the upstream source archives, hashes and reproducible memory-limit patch; `third_party/opendocument-core/` and `assets/licenses/office-engine-notices.txt` contain collected notices. The exact static dependency closure and all binary distribution obligations still require a release/legal audit.
- A ZIP signature, successful preview or format label does not prove the whole document is safe or faithfully rendered. Work on copies and choose a new destination; a platform save dialog can overwrite an existing file if the user selects it.

## Required validation before enabling or release

Run the complete Flutter suite with the owner's existing SDK, then test real DOCX/XLSX/PPTX/ODF and legacy documents, fonts, RTL, images, tables, formulas and malicious/oversized input. Compare preview and exported copies in independent applications. On physical Android devices test platform-view lifecycle, network isolation, WebView versions, accessibility, timeouts, low-memory behavior and interruption. Inspect the actual APK/AAB dependency and notice closure. Neither Node WASM tests nor Java policy/stub compilation prove any of these device behaviors.
