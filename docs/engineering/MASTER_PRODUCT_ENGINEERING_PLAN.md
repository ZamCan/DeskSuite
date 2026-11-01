# DeskSuite — Master Product Engineering & Workspace Design Plan

**Status:** Governing engineering directive  
**Repository:** https://github.com/ZamCan/DeskSuite  
**Default branch:** `main`  
**Platform strategy:** Android-first, offline-first, extensible to desktop  
**Relationship:** Complements `MASTER_ENGINEERING_DIRECTIVE.md`, `UNIFIED_PRODUCT_ARCHITECTURE.md`, and the visual identity directive.

## 1. Product contract

DeskSuite is one connected professional production environment, not a launcher containing unrelated mini-apps. It must let people create, capture, inspect, edit, process, organize, print and export supported content through reliable local workflows.

Priorities, in order:

1. Correctness and preservation of user data.
2. Genuine, testable capability.
3. Reliability, recoverability and clear failure handling.
4. Efficient user workflows.
5. Performance on ordinary devices.
6. Accessible, responsive and refined presentation.
7. Maintainability and controlled extensibility.

A screen, button, package, mock, sample or successful compile is not proof that a capability works. Every capability must have an identified engine, explicit support boundary, test evidence and known limitations.

## 2. Architecture boundaries

Preserve the existing Flutter/Dart application and its proven platform integrations. Evolve incrementally; do not create a parallel architecture or rewrite functioning modules merely to match a proposed folder layout.

Maintain these logical boundaries:

- **Application shell:** startup, lifecycle, routing, workspace registry, global settings and theme.
- **Workspace presentation:** task-focused UI, local state, contextual controls and user feedback.
- **Application services:** file selection, import/export, task coordination, search, recent activity, printing and sharing.
- **Processing engines:** image, camera, scan, OCR, PDF, Office, media, print layout and business calculations.
- **Persistence:** database and file metadata, project records, settings, original/working/output files, migrations and recovery.
- **Platform adapters:** Android camera, content providers, storage, print, share, desktop file access and other native services.

Processing logic must not live inside presentation widgets. Engines should be independently testable and callable by more than one workspace. Platform-specific behaviour must be behind explicit adapters where practical.

## 3. Shared file and operation model

Treat a file's stable internal identity separately from its name or current path. Preserve the distinction between:

- Original source.
- Working copy.
- Temporary intermediate.
- Saved project.
- Final export.
- Version/revision.

A file reference should carry only metadata required by its consumers: stable ID, display name, validated type, storage reference, size, timestamps, and relevant media dimensions/page count. Avoid loading large content into global application state.

Significant work should use a consistent operation lifecycle:

1. Validate input and supported format.
2. Check resource and permission requirements.
3. Create an identifiable operation request.
4. Execute using the appropriate engine.
5. Report real progress when measurable.
6. Support safe cancellation where possible.
7. Validate the produced output.
8. Save safely and verify the saved result.
9. Publish the result reference to the originating workspace.
10. Offer relevant next actions.

Represent waiting, preparing, processing, finalizing, completed, failed and cancelled states explicitly. Never fabricate percentage progress. A failed operation must not corrupt or silently replace its source.

## 4. Cross-workspace continuity

Implement shared handoff contracts so supported content moves without unnecessary export/re-import:

- Scanner → PDF Studio.
- Scanner → OCR review → Documents or text export.
- Photo Studio → PDF Studio.
- Photo Studio → passport/ID layout.
- Documents, Spreadsheets and Presentations → supported PDF export.
- PDF Studio → Files, print or share.
- Files → compatible workspace.
- Print production → print-ready output and saved project.

A handoff transfers a stable file reference and relevant context, not a stale screen object or a temporary path. Preserve source files, page order, resolution, metadata and edits as applicable. Make unsupported conversions explicit rather than guessing.

## 5. Engine contracts and capability truth

Every engine must document:

- Accepted input formats and size/dimension limits.
- Output formats and fidelity.
- Unsupported features.
- Resource profile and execution location.
- Error types and recovery behaviour.
- Data-preservation guarantees.
- Tests and independent output validation.
- Platform-specific restrictions.

Use a capability registry or equivalent central declaration where it prevents inconsistent claims across menus, conversion catalogues and workspaces. The UI must derive availability from real engine support. Do not create duplicate engines for the same operation.

## 6. Workspace engineering requirements

### Photo Studio
Use a single working-image context with non-destructive or recoverable edits. Support only verified crop, rotate, flip, resize, colour adjustment, cleanup, compression, conversion, background compositing/removal and print preparation. Distinguish actual segmentation-based removal from compositing an image that already has transparency. Preserve dimensions and quality according to the chosen output. Passport/ID layouts must use verified issuing-authority dimensions; never invent universal standards.

### Scanner
Use actual camera or imported-image input. Keep capture, boundary correction, perspective transform, cleanup, multipage organization, OCR, preview and export as distinct stages. Automatic detection must have a manual correction path. Treat image-only PDF and searchable OCR PDF as different outputs. Verify camera lifecycle, rotation, permission denial, cancellation, interrupted capture and low-memory behaviour on devices.

### PDF Studio
Distinguish reading/rendering, page manipulation, annotation overlays, form filling, text editing, encryption and digital signatures. Support only what the integrated engine can preserve. Validate output structure and reopen generated documents in independent readers. Encrypted or malformed inputs must fail safely with understandable messages.

### Documents
Distinguish viewing, content extraction, content editing, layout-preserving editing and conversion. Do not imply Word-compatible layout fidelity when only text/content is preserved. Test tables, images, styles, RTL text, fonts, headers/footers and complex documents; state unsupported areas.

### Spreadsheets
Maintain a real workbook/sheet/row/column/cell model. Formula support must be computed by an actual calculation engine or explicitly scoped implementation. Separate cell-value editing from formula recalculation and layout fidelity. Charts must derive from workbook data.

### Presentations
Maintain slide order, dimensions and embedded assets where supported. Distinguish content inspection, preview, slide editing and export. Do not present a viewer as a full presentation editor.

### Media
Use format-appropriate preview and playback paths. Respect codec/platform support, file sizes and memory limits. Avoid forcing every media type into one generic preview.

### Files, Folders and Projects
Provide reliable browse, search, sort, filter, preview, open, rename, move, copy, delete, share and export operations according to actual platform permissions. Confirm destructive operations. Handle missing content references and interrupted operations. Project membership should not create unnecessary duplicate file copies.

### Printing and stationery production
Use physical units and validated page geometry. Separate document page size, finished photo size, sheet size, margins, bleed and printer-specific capabilities. Preview the actual configured output. OS print handoff is not proof of physical printer calibration. Record driver/device limitations.

### Business and POS
Treat money as exact integer minor units or an equally safe decimal representation. Distinguish revenue, cash received, cost, gross profit, expenses, refunds, balances and stock valuation. Use transactional persistence for sales and stock movements before claiming ledger-grade reliability. Reports must derive from stored records; no demo values may appear as live business data.

## 7. Visual and interaction engineering

The visual system is governed by the DeskSuite signature identity directive. Light ice blue is a restrained recurring accent, not a full-screen dominant colour. Use balanced neutral surfaces, legible text, carefully controlled glass effects and workspace-specific iconography.

Do not use colour as a substitute for hierarchy. Professionalism comes from information architecture, spacing, typography, alignment, task clarity and consistency—not saturation or decoration.

Every workspace should be designed around its primary working object:

- Scanner: live capture or page review.
- Photo Studio: the image.
- PDF Studio: document pages.
- Documents: document canvas.
- Spreadsheets: workbook grid.
- Presentations: slide canvas.
- Files: file browsing and preview.
- POS: transaction entry and accurate totals.

Use progressive disclosure: show common actions first and reveal advanced controls in context. Remove duplicate descriptions, redundant cards, repeated navigation and decorative elements. Keep primary actions reachable on small phones. Adapt intelligently for larger screens rather than stretching mobile layouts.

Use a shared component system for typography, spacing, buttons, toolbars, dialogs, sheets, surfaces, focus states, empty/error states and motion. Workspace layouts may differ when the task requires it. Ensure accessible contrast, labels, touch targets, keyboard/focus behaviour and text scaling.

## 8. Data safety, privacy and recovery

- Preserve originals by default.
- Use atomic or transactional writes appropriate to the data.
- Validate inputs by content/container where possible, not extension alone.
- Apply explicit limits before expensive decode or processing.
- Handle disk-full, permission revocation, missing files, corrupt inputs and process interruption.
- Make migrations backward-compatible and test representative prior data.
- Avoid unnecessary permissions and network access.
- Keep essential workflows offline.
- Never transmit user content without a clearly disclosed, user-authorized feature.
- Do not claim encryption or secure deletion unless implemented and verified.
- Provide recovery paths for interrupted work where practical.

## 9. Performance engineering

Target ordinary Android devices. Use bounded decoding, thumbnails, lazy loading, streaming/incremental file processing, background isolates or native workers, cancellation and cache lifecycle management.

Do not load entire large workbooks, PDFs, image collections or videos into memory unnecessarily. Measure startup, workspace transition, rendering, processing duration, peak memory, cache growth and failure rates on representative devices. Host benchmarks are not Android-device performance evidence.

## 10. Verification and release gates

Use layered verification:

- Unit tests for algorithms, models, limits, calculations and serialization.
- Widget tests for navigation, state, screen sizes, text scaling and interaction.
- Integration tests for complete import → process → save → reopen → handoff workflows.
- Platform tests for native camera, content providers, printing, lifecycle and storage.
- Regression tests for existing supported workflows.
- Independent output checks for PDFs, Office packages and image dimensions/content.
- Accessibility and performance checks.
- CI builds for configured targets.

A section is complete only when the real operation, data safety, failure handling, UX, tests and platform limitations are verified. A green CI run verifies only the jobs and source commit represented by that run; it does not prove physical camera, printer, install or device performance.

## 11. Engineering execution protocol

Before changing a module:

1. Inspect the current implementation and tests on the target branch.
2. Identify existing engine and service reuse.
3. Record the current behaviour and support boundary.
4. Map dependencies and data flow.
5. Define the smallest coherent change.
6. Implement without removing unrelated functionality.
7. Add tests for the behaviour and failure cases.
8. Run relevant formatting, analysis, tests and builds.
9. Inspect diffs for unintended scope.
10. Update the capability register and engineering status with evidence.

Do not start several large engine rewrites simultaneously. Do not add dependencies without licence, platform, size, memory and maintenance review. Keep commits focused and traceable. Preserve the application ID and established user data unless a migration is explicitly designed and tested.

## 12. Implementation order

Proceed by dependencies, not by visual novelty:

1. Validate current Boot, Home and navigation foundation.
2. Audit and strengthen design system and responsive shell.
3. Audit shared file identity, storage, operation lifecycle and recovery.
4. Audit current engines and capability registry; close the highest-risk correctness gaps.
5. Validate Scanner and OCR workflows on Android.
6. Validate Photo Studio and print-preparation workflows.
7. Validate PDF Studio end-to-end.
8. Improve Office format fidelity with honest per-format support.
9. Complete Files/Projects and shared handoffs.
10. Strengthen printing and business/POS persistence.
11. Complete cross-workspace, accessibility, performance and release QA.

This sequence is a dependency guide. It does not authorize skipping the owner's existing approval gates. In particular, do not begin internal workspace redesign until the current Boot/Home/Side Navigation foundation has been reviewed and approved.

## Final standard

DeskSuite is judged by the professional work it can reliably complete, the integrity of the results, the clarity of its limitations, and the ease with which users complete real tasks—not by the number of screens, buttons, animations or advertised features.

**Build real capability. Preserve user work. Connect the workflows. Present only what is useful. Verify before claiming completion.**
