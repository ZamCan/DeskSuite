# DeskSuite repository engineering audit — 2026-11-01

**Repository:** https://github.com/ZamCan/DeskSuite  
**Branch audited:** `main`  
**Source snapshot inspected:** `cf35d1988267b9dc6567c8752568be0c043a71df`  
**Audit type:** Remote source/tree/documentation inspection; not a physical-device audit.  
**Governing plan:** [MASTER_PRODUCT_ENGINEERING_PLAN.md](MASTER_PRODUCT_ENGINEERING_PLAN.md)

## 1. Executive finding

DeskSuite already contains a meaningful body of local processing code. The next phase should be consolidation, verification and strengthening of shared foundations—not a wholesale rewrite and not a sequence of disconnected screen redesigns.

The repository contains Flutter/Dart application code, Android Kotlin/Java integrations, bundled OCR language data, an optional OpenDocument.core WebAssembly preview asset, tests, engineering documentation and CI/build scripts. The recursive Git tree inspected on 2026-11-01 contained 434 entries and was not reported as truncated.

The latest known matrix run, [41261807220](https://github.com/ZamCan/DeskSuite/actions/runs/41261807220), completed with conclusion `success` for commit `cf35d1988267b9dc6567c8752568be0c043a71df`. This verifies that workflow run only. It does not prove physical Android camera behaviour, printer output, release signing, installation, device performance or visual approval.

## 2. Repository architecture observed

### Application and presentation
- `lib/main.dart`: Flutter application initialization, theme selection, repository creation and workspace entry.
- `lib/app/`: startup/brand launch, motion, section artwork, theme and stationery pattern.
- `lib/workspace/workspace_screen.dart` and `workspace_widgets.dart`: primary workspace shell, navigation and presentation.
- `lib/legacy_studios.dart`: restored legacy studios remain in a large combined source file; future refactoring should be incremental and test-led.
- `lib/design/`: editable design document, controller, renderer, geometry and editor UI.

### Storage and file handling
- `lib/core/`: file and image limits, atomic replacement, local file store, paths, IDs and page limits.
- `lib/workspace/file_gateway.dart`: native file selection/export boundary with bounded imports.
- `lib/workspace/project_repository.dart`: project persistence and migration/workspace repository.
- `lib/workspace/`: conversion catalogue, file gateway, project repository, shortcut search and workspace routing.

### Processing and platform integration
- `lib/images/`: photo processing, optimization, image cleanup and physical sizing.
- `lib/document_scan/`: camera gateway, scan draft, corner editing, page geometry, cleanup, scan processing and PDF generation.
- `lib/ocr/`: OCR orchestration/preparation, text review/export and searchable PDF.
- `lib/pdf/`: PDF Studio, inspection and combination.
- `lib/office/`: office format detection, bounded package handling, readers/writers, content editing, preview and conversion.
- `lib/printing/`: print gateway, print jobs, paper catalogue, photo sheets and export.
- `lib/business/`: inventory/settings and receipt foundations.
- `android/app/src/main/kotlin/com/zamcan/desksuite/`: Android camera activity, main activity and OCR channel.
- `android/app/src/main/java/com/zamcan/desksuite/`: camera math and Office preview bridge/policy.
- `android/app/src/main/assets/office_engine/`: OpenDocument.core WASM preview assets and viewer; the existing engineering documentation describes this preview as optional, read-only and disabled by default.

## 3. Evidence-based capability and risk register

| Area | Source evidence found | Current engineering interpretation / next verification |
|---|---|---|
| Startup, shell and navigation | `lib/app/*`, `lib/workspace/workspace_screen.dart`, navigation tests | The first three visual stages are being validated. Latest CI passed. Still require owner review of the actual running UI before treating visual identity as accepted. |
| Image processing | `lib/images/photo_processor.dart`, `image_optimizer.dart`, cleanup and sizing modules | Real local transformations exist. Verify edge cases, large images, quality/dimension reporting, metadata decisions, source preservation and real-device memory. Do not imply automatic semantic background removal where only compositing exists. |
| Camera and scanning | `lib/document_scan/*`, Android `DocumentCameraActivity.kt`, `CameraCaptureMath.java` | Capture and scan processing foundations exist, including manual correction and cleanup. Verify hardware lifecycle, permission denial, rotation, interrupted capture, preview limits and memory on physical Android devices. Automatic boundary suggestions are not a guarantee of correct detection. |
| OCR | `lib/ocr/*`, Android `OcrChannel.kt`, bundled `assets/tessdata/` | Offline native Tesseract integration and English/Kiswahili model assets are present according to the engineering register. Device recognition accuracy, language behaviour, lifecycle, memory, coordinates and searchable-PDF fidelity remain device-validation gates. |
| PDF | `lib/pdf/pdf_studio_page.dart`, `pdf_inspection.dart`, `pdf_combine.dart`, scan/searchable-PDF modules | PDF inspection and selected operations are implemented in source. Validate malformed/encrypted inputs, page fidelity, limits, cancellation, save/reopen and independent readers. Do not infer complete Acrobat-like editing or secure encryption from a viewer/annotation path. |
| Office | `lib/office/*`, Android Office preview bridge and WASM assets | Content-oriented reading/writing/conversion and a separate read-only preview exist. Formatting, images, charts, formulas, legacy binary formats and complex layout need explicit per-format limits and independent-app fidelity tests. Do not claim full Microsoft Office compatibility. |
| Design and creative production | `lib/design/*`, `lib/workspace/creative_studio_page.dart`, template catalogue | Editable design documents and rendering are present. Validate project round-trips, image placement, export fidelity, template provenance and print geometry. |
| Printing | `lib/printing/*` | Print PDF generation and platform handoff foundations exist. Physical printer discovery, scaling, colour, margins, media handling and actual paper output are not proven by host fakes or successful CI. |
| Files and projects | `lib/core/*`, `lib/workspace/file_gateway.dart`, `project_repository.dart` | Bounded picker and local project/file persistence exist. This is not automatically a full system-wide file manager. Verify content URI persistence, move/copy semantics, process death, storage full, backup/restore and cross-workspace references. |
| Business / POS | `lib/business/inventory.dart`, `sale_receipt.dart`, business tests | Inventory and receipt/sales foundations exist. Do not describe as a complete POS/financial ledger until transactional stock/sales persistence, returns, expenses, balances and reports are implemented and reconciled. |
| Shared workflows | `test/workflow_integration_test.dart`, `test/widget_flow_test.dart`, module-specific handoff code | Some cross-module flows are exercised. A stable central file-reference and operation lifecycle is still the key architecture audit target. Confirm source identity, ownership, cancellation, recovery and output registration. |
| Storage safety | `lib/core/atomic_file_store.dart`, `local_file_store.dart`, `suite_paths.dart`, project repository | Atomic replacement and bounded local storage foundations exist. They are not a complete transactional database or backup system. Review concurrency scope, multi-file commits, migrations, crash recovery and file-reference integrity. |
| CI and release | `.github/workflows/build.yml`, `tools/build-android.sh`, Android Gradle files | The latest recorded workflow run passed. Release signing, installed-package validation and actual-device execution remain separate gates. Never commit keys or credentials. |

## 4. Testing inventory observed

The repository includes tests for brand/startup/theme, navigation and workspace routing, file gateway and local storage, design engine, image processing/optimization, scanning and scan draft recovery, OCR preparation/exports/searchable PDF, Office package/read/write/preview/conversion, PDF inspection/combination/studio, printing/photo sheets, inventory/receipts, and workflow integration.

The latest CI success is a useful regression checkpoint. For each new engine change, inspect the exact workflow job matrix and logs rather than relying on an old test count or a historical status document. Device-specific tests must be recorded separately from host tests.

## 5. Highest-priority engineering risks

1. **Shared file identity and workflow lifecycle:** ensure a stable file reference, source/working/output distinction, task lifecycle, cancellation and result registration across workspaces.
2. **Real-device verification:** camera, OCR, content providers, large images, PDF rendering, WASM preview, printing and Android lifecycle cannot be fully verified by widget tests.
3. **Office fidelity:** explicitly scope text/content-level support and read-only preview versus full layout editing. Build a representative format fixture matrix.
4. **PDF correctness and limits:** validate encrypted/corrupt documents, independent reader compatibility, save/reopen, page order, page sizes and low-memory behaviour.
5. **Data safety:** atomic single-file writes do not by themselves guarantee transactional multi-file workflows, crash-safe business ledgers or full backup/restore.
6. **Performance:** record actual device memory and processing timings before selecting additional native engines or bundling large models.
7. **Business integrity:** strengthen transactional sales/stock accounting before expanding dashboards or financial reporting.
8. **Visual acceptance:** CI success does not replace the owner's review of actual Boot/Home/Navigation visuals and screen-size behaviour.

## 6. Recommended implementation order

1. Complete the existing Boot, Home and Side Navigation review and acceptance gate.
2. Inspect and document the current design tokens, icon system, responsive shell and shared UI components; apply the restrained DeskSuite signature accent without recolouring every surface.
3. Map file identity, storage roots, working copies, exports and project references.
4. Define or strengthen the shared operation/task lifecycle and file handoff contracts.
5. Run a focused correctness audit of existing image, scan, OCR, PDF and Office engines; fix the highest-risk defects rather than rewriting.
6. Validate native Android camera/OCR and large-file performance on the owner's actual device.
7. Validate end-to-end Photo Studio, Scanner and PDF workflows.
8. Improve Office fidelity and file management with explicit capability boundaries.
9. Strengthen print-production and business/POS persistence.
10. Complete cross-workspace regression, accessibility, performance and release verification.

## 7. Scope and evidence rules

This report is a source-tree and existing-document inspection. It is not a claim that every listed source file has been executed or that every described engine is fully functional.

Before implementing a change, fetch the latest `main` ref again and inspect the target code and tests. Keep changes small, preserve existing features, add tests, and update the capability register. Record host CI, Android build, device execution, physical printer and owner visual approval as distinct evidence categories.

**Audit conclusion:** strengthen the shared foundations and verify the existing engines. Do not begin a broad workspace redesign or add decorative feature surfaces ahead of real capability, data integrity and the existing visual approval gates.
