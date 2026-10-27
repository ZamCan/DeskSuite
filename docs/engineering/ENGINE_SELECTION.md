# DeskSuite engine selection and integration strategy

Status: architecture decision record; implementation must be validated against actual target SDKs, dependency licenses and device builds before a dependency is accepted.

## Core decision

Keep Flutter/Dart for the shared application shell, navigation, accessible workflows and business logic that can be shared. Do not force image processing, document detection, OCR, PDF internals, office parsing or printing into Flutter-only implementations. Use platform channels or small platform adapters when Android-native APIs or libraries are the strongest option.

Every engine must sit behind a stable interface and return a common result containing output URI/path or bytes, detected format, dimensions/pages where applicable, warnings, duration, cancellation/failure state and validation outcome. Long tasks run off the UI thread and report progress. User-selected input is read-only unless the user explicitly chooses a destructive operation.

## Engine decisions by capability

| Capability | Preferred evaluation path | Important acceptance condition |
|---|---|---|
| Camera | Android CameraX through a maintained Flutter adapter or a thin native Kotlin bridge when plugin controls/lifecycle are insufficient | Real capture, supported focus/exposure/torch controls, orientation handling, lifecycle recovery and permission denial tests |
| Document boundary detection / perspective correction | Evaluate OpenCV (Apache-2.0 distribution) or a maintained scanning SDK; keep manual four-corner crop as a fallback | A known perspective-distorted sample must produce a valid, correctly oriented image; no automatic crop is accepted without preview |
| Image processing | Native Android bitmap/NDK or maintained Dart/native image libraries, selected by tested formats and memory use | Exact dimensions, format decoding, orientation, alpha handling and output size must be asserted in tests |
| OCR | Compare offline-capable ML Kit text recognition options with Tesseract-based integration for required languages, model delivery, licensing, accuracy and APK size | Known sample corpus, language-specific tests, confidence/uncertainty display and optional text-layer PDF output |
| PDF viewing/manipulation | Evaluate a maintained Android PDF renderer/library and a cross-platform library for the exact operations required; retain the existing `pdf` package for creation where suitable | Separately test reading, page rotation/reorder/extract/merge, annotations, form filling and encrypted files; do not equate rendering with editing |
| DOCX/XLSX/PPTX and ODF | Evaluate a real office engine such as LibreOffice in a separate supported runtime/service, plus narrower format-specific libraries for tasks that do not require full fidelity | Round-trip fixture tests must verify text, styles, tables, formulas, slide content and embedded assets appropriate to each supported route |
| Spreadsheet formulas | Use an actual spreadsheet engine or clearly bounded formula library; do not implement a misleading generic formula parser | Explicit supported formula subset, recalculation tests and preserved unsupported formulas |
| Flyer/poster/editor | Extend the current editable design model and renderer; consider SVG/vector support and font management deliberately | Layers remain editable in project files; export dimensions and print sizing match the document model |
| Passport / ID photo preparation | Deterministic crop, physical size/DPI math, background tools where feasible and multi-photo sheet imposition | Exact pixel/physical dimensions are tested; any authority-specific biometric/background rules are configurable and never implied universally |
| Print production | Build a print-job model, page imposition/layout engine and OS-specific print/export adapters | Preview matches output page count, dimensions, margins and ordering; printer-specific color calibration is not claimed without hardware testing |
| Stationery-shop POS | Local database and transaction/service layer, independent of UI; SQLite is an appropriate candidate after migration and recovery design | Sales and stock changes are atomic, receipt totals reconcile, return/void actions are audited, and backups can be exported |
| Cloud files | Optional provider-specific adapter using supported authorization; local workflow must work without it | No embedded secrets, minimum scopes, explicit user action, retry/resume and disconnect handling |

These are evaluation decisions, not claims that any listed engine is already integrated. Verify the current supported versions, Android SDK compatibility, maintenance activity, license obligations and transitive dependencies before pinning a dependency.

## LibreOffice and office compatibility

LibreOffice is a full office suite, not a lightweight Flutter widget or universally embeddable Android library. Do not add a dependency that merely renders documents and advertise it as editable Office compatibility.

Three viable deployment shapes should be investigated:

1. **On-device office runtime:** strongest offline/privacy potential and useful fidelity, but the hardest packaging, Android integration, ABI, startup, memory and license-compliance work. Accept only after a real Android proof-of-build and redistribution review.
2. **Optional self-hosted conversion service:** potentially practical for broad conversion, but needs infrastructure, operations, privacy controls, transport security and cost monitoring. Never make it a prerequisite for offline scanning and image work.
3. **Narrow local format adapters:** smallest initial footprint, but each format and operation has limited fidelity. Publish a precise support matrix and preserve originals.

Do not select option 2 by default for a low-cost, offline-first product. First test whether an on-device runtime can be maintained within practical Android limits; if not, ship honest narrow local workflows and keep the optional service boundary available for later. Full DOCX/XLSX/PPTX editing is a separate milestone from previewing or converting these formats.

## Office format support contract

A format is supported only for explicitly named operations. Example: “PPTX preview” does not imply slide editing; “XLSX cell editing” does not imply formula recalculation; “PDF annotation” does not imply modification of existing PDF text.

For each input/output route, maintain:
- engine and version;
- supported operation and format;
- offline/online requirement;
- preservation/fidelity expectations;
- input size and resource limits;
- license/redistribution notes;
- fixtures and validation checks;
- known loss and user-facing warning.

Reject unsupported files with an actionable message. Do not rename extensions or silently discard macros, formulas, embedded fonts, images, animations, tables or metadata.

## DeskSuite product areas that must share the same foundations

- **Document studio:** capture, scanning, OCR, PDF and office documents.
- **Image/photo studio:** crop, cleanup, retouching, exact-size photos, batch jobs and export.
- **Design and print studio:** flyers, posters, labels, cards, layouts, templates, DPI checks and imposition.
- **Stationery business:** catalog/inventory, purchasing, sales, receipts, expenses, customer print jobs and reports.
- **File workspace:** import, recent items, project/file metadata, safe export and recovery.

They should share a file gateway, processing queue, job progress/error model, export validation and design system. Keep business transactions separate from creative document models.

## Rollout gates

1. **Gate 0 — Audit and CI repair:** baseline is documented; current editor tests and platform CI are stable.
2. **Gate 1 — File and image foundation:** format sniffing, safe temp files, exact resize/crop/rotate/encode, tests and file integrity.
3. **Gate 2 — Camera scanning:** capture, manual crop, perspective correction, multipage state and PDF creation.
4. **Gate 3 — OCR and searchable PDF:** offline engine, confidence handling, review/edit text and independent output validation.
5. **Gate 4 — PDF workspace:** read/navigation and each manipulation operation tested independently.
6. **Gate 5 — Office engine decision:** real runtime/format fixture prototype before committing to full Office claims.
7. **Gate 6 — Design/photo production:** exact physical sizing, photo sheet layout, print presets, layers and batch exports.
8. **Gate 7 — Stationery POS:** schema/migrations, atomic sales/stock, receipts and reconciled reports.
9. **Gate 8 — Hardening and release:** resource profiling, licensing/security review, persistent signing and device testing.

At every gate, do the highest-value complete workflow first; do not add unrelated screens while the current engine remains a placeholder.
