# DeskSuite baseline audit

Audit date: 2026-10-27
Audited branch: `main`
Audited commit: `b2d22cb0691eab3d3e39ccdb6cb14156f0b34f4f`
Application ID: `com.zamcan.desksuite`
Framework: Flutter / Dart; Android runner present
Audit method: repository README, pubspec, architecture and format documentation, active workspace implementation, and GitHub Actions workflow.

## Executive finding

DeskSuite currently has a real, bounded local design editor. It is **not yet** a document-scanner, office suite, full photo editor, PDF editor, or stationery POS. The next step must add engine boundaries and real capabilities without pretending Flutter widgets alone provide those engines.

The product owner’s requirement is accepted: Flutter may remain the shared UI shell, but a capability must be implemented by the best maintainable engine available for the target platform. Platform-native Android components, established libraries, or a separately packaged office engine are valid choices behind stable interfaces. No dependency is to be added solely to make the feature list look larger.

## Evidence-based capability matrix

| Capability | Current verified state | Evidence / location | Required action |
|---|---|---|---|
| App shell and navigation | Implemented, limited | `lib/main.dart`, `lib/workspace/workspace_screen.dart` | Keep and extend in coherent feature areas |
| Local design editor | Implemented, bounded | `lib/design/` | Preserve; expand layers, typography, templates and export carefully |
| Editable design project storage | Implemented, versioned JSON | `lib/workspace/project_repository.dart` | Add migrations, recovery tests and user-selected backup/export |
| Import/export boundary | Partial | `lib/workspace/file_gateway.dart` | Extend with explicit open/save destinations and safe content validation |
| PNG export | Implemented with limits | `lib/printing/design_export.dart`, `docs/FILE_FORMATS.md` | Keep dimension and memory bounds; test actual decoded output |
| PDF output | Implemented, one-page raster PDF | `lib/printing/design_export.dart`, `docs/FILE_FORMATS.md` | Do not call it a full PDF editor; add real PDF engine for reading/manipulation |
| Camera capture | Not implemented as a production workflow | Current dependencies contain no camera engine | Add camera service and lifecycle-safe capture |
| Document scanning / perspective correction | Not implemented | No scan/detection pipeline in current dependency set | Add edge detection, manual corner editing, perspective warp and enhancement |
| OCR / searchable PDF | Not implemented | No OCR dependency or pipeline | Evaluate offline OCR engine and text-layer PDF generation |
| PDF open/read/merge/split/annotate/forms | Not implemented | Current PDF dependency is output-oriented | Integrate a maintained PDF engine; define operation-by-operation support |
| Image crop/resize/rotate/quality conversion | Partial at most; no complete image workspace | Current app imports image layers and rasterizes designs | Add a central image-processing service with verified pixel output |
| Passport/photo studio | Not implemented | No print-size presets or photo workflow | Implement exact physical dimensions, DPI checks, sheet layout, crop and non-destructive adjustments |
| Flyer/poster/print design | Basic editable canvas exists | `lib/design/` | Expand into a production layout engine; distinguish current canvas from advanced design parity |
| DOCX/XLSX/PPTX editing | Not supported | `docs/FILE_FORMATS.md` | Select a genuine office engine; never use extension renaming or render-only claims |
| ODT/ODS/ODP/RTF/TXT/HTML | Not supported as general editable office workflows | `docs/FILE_FORMATS.md` | Add format-specific readers/writers and conversion tests where practical |
| Stationery inventory/POS/accounting | Not integrated | README identifies prototype catalogue/stock decrement as archived, not active | Migrate into a tested local business module with sales, stock, receipts and reports |
| Printing queue / imposition | Not implemented | README and printing documentation | Add production job model, page layout/imposition, output preview and printer-aware constraints |
| Cloud storage | Not implemented | No configured connector in active code | Optional, consent-based provider adapter; offline core remains complete |
| Tutorials / sample library | Not implemented as real processing tutorials | No verified bundled processing pipeline | Bundle synthetic samples and route them through production services |
| Branding / launcher assets | Partial / requires verification | Repository has in-app brand styling; asset linkage not fully audited here | Verify generated Android adaptive/legacy icons and splash resources against build |
| Automated tests | Present for bounded current editor | `test/`, `.github/workflows/build.yml` | Add unit, integration and workflow tests for each new engine |
| CI Android APK/AAB | Configured | `.github/workflows/build.yml` | Verify each new commit's workflow results and artifacts |
| Desktop CI | Configured but previously failed on Windows widget test | Recent CI history summarized in handoff; workflow mutates platform scaffolds | Repair failing test/workflow; do not call desktop production-ready until independently verified |
| Release signing | Not a verified production signing channel | README explicitly describes CI builds as validation builds absent persistent signing | Configure protected signing secrets and verify upgrade continuity before release distribution |
| iOS | Unsigned validation only | CI workflow uses `--no-codesign` | Do not call it a store-ready IPA |

## Dependency baseline

The current `pubspec.yaml` contains Flutter, `file_picker`, `path_provider`, and `pdf`, plus Flutter test/lint tooling. It does not currently include a camera package, OCR engine, image-processing engine, office engine, spreadsheet formula engine, database, or cloud SDK.

## Immediate engineering rules

1. Preserve `com.zamcan.desksuite` and the active modular editor.
2. Keep the original source file unchanged by default; process to a new output and validate it before offering save/share.
3. Put processing behind service interfaces rather than implementing engines inside screen widgets.
4. Each format route must declare its engine, local/remote behavior, fidelity limits and validation.
5. UI visibility is not evidence that an operation works.
6. Flutter is the UI/orchestration choice, not a restriction on native Android or bundled engines.
7. Heavy office conversion must be evaluated as a separate runtime/service or a deliberately packaged platform engine, not assumed to be a small Flutter plugin.
8. Stationery-business management is a first-class DeskSuite product area, not an unrelated prototype screen.
9. A workflow is complete only after an automated test verifies its output and the relevant build succeeds.
10. Keep cloud services optional and do not introduce paid APIs as a default dependency.

## Phase gate

This audit establishes the baseline only. It does not claim that the missing capabilities are implemented. See `ENGINE_SELECTION.md` for the integration strategy and decision gates.
