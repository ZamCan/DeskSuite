# DeskSuite engine, package and tool integration register

**Purpose:** one source of truth for which engines are actually integrated, which dependencies they use, what they can do, and which gates remain before release. A package in a lockfile or a documented idea does not count as an integrated engine.

## Integration rules

1. Each capability has one canonical Dart/service interface; screens call the service, not third-party libraries directly.
2. Pin dependencies and native binaries, record exact versions, ABI/platform coverage, licence/attribution, bundled assets/models, network behavior, privacy implications and update policy.
3. Bound input bytes, decompressed size, dimensions, time, memory and output size. Process expensive work away from the UI thread where supported. Preserve the source, support cancellation/failure, and independently validate output.
4. Test real representative files and malformed/oversized fixtures. A fake platform adapter or host unit test does not establish Android/native-device behavior.
5. Prefer local/offline deterministic engines. Any optional model/runtime must be disclosed, downloaded only with explicit consent, version/hash checked, removable, and never required for core editing/printing.
6. Never label a route supported because its dependency exists. The conversion registry, UI, docs and tests must agree on actual capability and fidelity.

## Current engine inventory

| Capability | Current engine/integration | Current truth | Required next gate |
|---|---|---|---|
| Image decode/transform | Dart image package; shared bounded photo processor | Local decode, orientation correction, crop/rotate/flip/resize, PNG/JPEG, solid background compositing, selective speck cleanup; bounded input and output | Profile colour/EXIF/alpha/animation edge cases, output fidelity, memory and responsiveness on target Android |
| Image compression | lib/images/image_optimizer.dart using image JPEG encoder | Offline JPEG quality, byte-reduction and target-KB modes; preset/custom pixel dimensions; review before saving copy | Full CI pass, verify codec behavior on real photos, batch workflow and format/metadata preservation decisions |
| PDF writing | Dart pdf package | Generates image/text PDFs, photo sheets, design output and OCR searchable PDFs; it is not an existing-PDF reader/editor | Independent reader validation, huge-page limits, encryption path and PDF malformed-output checks |
| System printing | printing package and PrintGateway seam | Generates PDF and hands it to platform print UI | Actual printers/drivers, supported media, scaling, margins, paper selection, cancellation and printer-job lifecycle on devices |
| OCR | Native Tesseract4Android 4.9.0; Tesseract 5.5.1; Leptonica 1.85.0; Kotlin OcrChannel; bundled eng and swa tessdata_fast LSTM models | Integrated offline Android OCR; models ship in assets/tessdata/ and are copied to app-private storage. No runtime model download. Supports English and Kiswahili; confidence/word boxes feed review and searchable-PDF output | Build and test on actual Android ABI/API levels; benchmark printed and photographed documents in both languages, lifecycle/large files, model checksums, memory, recognition accuracy and PDF word positioning. Handwriting and other scripts are not claimed |
| OCR preparation/review | lib/ocr/ Dart services and Flutter review UI | Bounded orientation-corrected preparation, editable text review, confidence warnings, TXT/DOCX and searchable PDF | Validate user workflow and quality on real devices and varied inputs |
| Office package reading/writing | Dart archive + xml; lib/office/ package readers/writers and conversion registry | Content-level DOCX/XLSX/PPTX/ODF/RTF/TXT/HTML routes with explicit fidelity limits; not full-layout Office compatibility | Test independent applications and real-world files; formulas/media/RTL/layout fidelity; optional external engine seam |
| External Office engine | ExternalOfficeEngine capability seam | Optional soffice discovery is a design path; not bundled and not assumed present | Real executable detection, argument escaping, sandbox/temp handling, output validation and per-platform integration |
| Image/PDF/file handoff | file_picker, image_picker, path_provider, native content/file and print adapters | Dependencies are integrated; native providers and lifecycle still need device checks | Content URI, permissions, process death, storage full, overwrite confirmation, export reopening |
| Local storage/project formats | Existing workspace repository and versioned .dsdesign JSON | Existing files and per-feature data paths are retained; complete suite backup/restore and shared asset registry are not complete | Crash-safe migrations, atomic writes, cross-ID import, asset provenance and full backup/restore |
| Small language model (SLM) | NOT YET INTEGRATED | No SLM runtime/model is part of the current verified implementation. Tesseract OCR is not an SLM and remains the deterministic OCR baseline | Evaluate a small local runtime such as llama.cpp-compatible inference or another maintained Android-capable runtime. Check native build/ABI, quantization, model licence, RAM, latency, battery, APK/download size, privacy and offline behavior. Only then implement an optional LocalLanguageModel adapter for reviewed OCR correction/layout suggestions; never silently replace source text or make core workflows depend on it |
| Existing-PDF reader/manipulation | NOT YET INTEGRATED | PDF generation is not PDF import, rendering, merge, split, annotation or compression | Evaluate maintained Android/PDFium/native candidates, encryption/malformed-file safety, licence/ABI, render/search accuracy, memory and per-platform parity before selecting an engine |
| Background removal/segmentation | NOT YET INTEGRATED | Solid-background compositing only works for already-transparent images; it does not remove a background | Compare classical/manual masking and optional local segmentation models; benchmark hair edges, lighting, RAM, offline install and licences |
| Secure PDF/PIN | NOT YET INTEGRATED | Current PDF exports are not encrypted | Choose a maintained, interoperable encryption implementation; verify encryption and test correct/wrong passwords with independent PDF readers. A cosmetic PIN screen is prohibited |
| Print production/media catalogue | Photo-sheet geometry + design canvas/export | Photo sheet now offers a wide set of standard paper/photo/poster sizes and custom media; printer capability, margins and actual output are not inferred | Share one catalog across photo sheets and document/design canvases, cover ISO A/B/C, US sizes, photo paper, card/badge, roll and custom poster media, add media capability profiles, bleed/crop marks and DPI-aware export that respects device pixel budgets |

## SLM acceptance protocol

The SLM is an optional local assistant engine, not an OCR replacement and not a marketing-only label. The first useful scope is human-reviewed OCR correction, heading/paragraph grouping, and layout suggestions. Do not send document text off-device. Do not execute model output as code or use it to make irreversible edits. Keep original OCR text and every suggested change diffable and undoable.

Before selecting a runtime, record a reproducible benchmark on the lowest supported target device: model name/version/hash/licence, quantization, download/storage size, cold-start time, tokens/second, peak RAM, battery/thermal behavior, cancellation, airplane-mode behavior and result quality on a fixed synthetic/consented fixture set. The core product must remain usable when the model is absent, disabled or fails to load.

## Package release gate

Before a release, regenerate dependency notices from the resolved lockfile; audit native AAR/JNI/ABI contents, Gradle plugins, platform permissions, fonts, sample images, Tesseract language data and any selected model/runtime. Record checksums and licences, verify Android APK/AAB contents and size, and test actual offline operation. Do not claim all package/licence checks complete from THIRD_PARTY_NOTICES.md alone: it explicitly says nested native binary review remains outstanding.
