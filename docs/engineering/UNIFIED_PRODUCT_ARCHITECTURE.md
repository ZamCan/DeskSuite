# DeskSuite unified product architecture and integration plan

**Owner:** ZamCan (Mussa Fikiri Ngwegelo)  
**Status:** Architecture contract and implementation gates; not a claim that listed future capabilities are already implemented.  
**Product principle:** One product, shared engines, coherent workflows, no duplicate mini-apps.

## 1. Product definition

DeskSuite is an Android-first, local-first creative, office, document-capture, print-production and stationery-business workspace. PDF is a document format and one workflow, not the product's centre.

Capability references include Acrobat, Photoshop, Canva, WPS Office, Microsoft Office and CamScanner. These are capability benchmarks only; DeskSuite must use its own identity and must not claim parity until the relevant acceptance tests pass.

## 2. Product areas, one application

1. **Home / Files** — recent work, projects, imports, search, templates, status, recovery and one consistent file browser.
2. **Studio** — document and page design; reusable layouts; typography; shapes; image placement; guides, snapping, layers and history. The existing creative editor remains the foundation rather than spawning another editor.
3. **Image Lab** — crop, rotate, resize, perspective, colour/tonal controls, compression, transparency, selection/layer workflows and safe exports. Reuse the shared image pipeline and common asset references.
4. **Capture** — camera/import, multi-page capture, edge detection with manual fallback, perspective correction, cleanup, OCR, page ordering and scan-to-document workflows.
5. **Office** — document, spreadsheet and presentation content editing, tables, page setup, supported format import/export and explicit fidelity warnings. A package parser is not a full layout-compatible Office engine.
6. **PDF & Print** — open/render/search existing PDFs, page reorder/rotate/extract/merge, annotations where supported, export, print preview and OS print handoff. PDF generation alone is not a PDF reader/editor.
7. **Business** — stationery catalogue, variants/SKUs, stock ledger, basket/checkout, sale lines, receipts, customers/suppliers, expenses, balances, print jobs and business reports. Inventory and sales must be transactional, not a collection of unrelated JSON counters.
8. **Settings & Help** — privacy/storage, theme, accessibility, supported-format catalogue, onboarding, diagnostics and recovery guidance.

These are coordinated workspaces within the same shell and design system, not separate apps or independently themed screens.

## 3. Shared engine layer

Use stable Dart interfaces for orchestration and deterministic local processing; use native/platform engines where they offer materially better capability. Flutter widgets are presentation and interaction components, not the image, document, OCR, office or financial engine.

- **File and project core:** content-type detection, bounded import, URI/file gateway, project/asset IDs, metadata, atomic writes, safe temporary files, migrations, recent files, recovery and export verification.
- **Asset service:** one canonical asset store with metadata, dimensions, MIME type, hashes, provenance, thumbnails, licensing and reference counts. Editors refer to asset IDs rather than making duplicate copies into unrelated feature folders.
- **Document model/rendering:** shared page geometry, physical units, typography, vector primitives, image placement, z-order, transforms, undo/redo and versioned project serialization. Use the same model for on-screen preview, raster export and print/PDF output wherever fidelity permits.
- **Image pipeline:** bounded decoding, EXIF orientation, transforms, crop/perspective, colour adjustment, denoise/cleanup, resize, compression, thumbnail generation and output validation. Expensive operations run off the UI thread with cancellation and memory limits.
- **Capture/OCR:** native camera and file-provider boundaries; automatic edge detection plus manual correction; offline OCR with declared language models; editable recognition review; page-coordinate text layer for genuinely searchable PDFs. Never silently download models.
- **Office compatibility:** isolated readers/writers for formats with documented feature support; fixtures from real files; fidelity labels; preserve source files; optional external engine adapters. Do not describe content-level XML editing as full Word/Excel/PowerPoint editing.
- **PDF adapter:** explicit reader/rendering, text extraction, page-operation, annotation and writer interfaces. Evaluate maintained native engines, licence/notice obligations, Android ABI support, malformed-file safety, memory, password handling and device performance before adoption. The Dart PDF writer is not a reader.
- **Print production:** physical dimensions, DPI, paper profiles, margins, bleed/crop marks, page imposition, photo sheets, printer handoff and print-job tracking. Do not promise colour or printer accuracy without calibration tests.
- **Business ledger:** integer minor-unit money, immutable sale lines, stock movements, refunds/voids, supplier and expense records, audit history and database transactions. Reports derive from ledger entries, not independently editable totals.
- **Platform adapters:** Android camera, content URI, file picker, share, print, lifecycle and secure storage boundaries; shared domain logic remains reusable for desktop. iOS/Windows/Linux support is a tested target, not inferred from using Flutter.

## 4. Integration and dependency rules

- Keep one canonical app shell, route registry, theme/token set, typography system, icon registry, localization/accessibility conventions and settings source.
- Move the remaining large legacy studio file into bounded modules only when imports and tests prove behaviour is preserved; do not duplicate screens or rewrite working modules just for aesthetics.
- Define engine interfaces and acceptance fixtures before swapping implementations. Feature screens call shared services; services do not import screens/widgets.
- Centralize dependencies and adapters. Pin versions, review maintenance/security and licensing, record attribution/notices, and measure APK size, cold start, memory and latency before adopting native engines.
- Keep bundled logos, launcher/splash assets, tutorial samples, icons and fonts in a documented asset catalogue with source/licence, dimensions, purpose and a single canonical file per asset. Avoid scattered duplicate logos, generated placeholders and unused assets.
- Maintain a conversion registry as a capability truth source: input/output, implementation, fidelity, resource bounds, tests and limitations. The UI and documentation must be generated from or checked against this source.
- Preserve application ID `com.zamcan.desksuite`, existing project data and all branches. Never force-push, delete existing user files or silently overwrite imports. Keep credentials and signing keys out of the repository.

## 5. Visual design contract

Use the owner-selected dimensional blue DS scan-frame identity with clear, premium hierarchy. Avoid unrelated visual systems, emoji as brand marks, or a web-dashboard card for every operation.

- Shared spacing, typography, colour, shape, elevation, focus and motion tokens.
- Navigation is consistent across phone and desktop; frequent actions remain obvious and accessible.
- Editors prioritize canvas/work area and contextual toolbars; business screens prioritize fast entry, legible totals and reliable checkout.
- Light/dark themes, scalable text, keyboard navigation, semantics and contrast are product requirements.
- One icon family and a curated asset catalogue. Screens should feel related without forcing every workflow into an identical layout.

## 6. End-to-end acceptance workflows

1. **Paper to usable document:** capture/import → detect/correct page → clean → OCR → edit recognized text → searchable PDF or editable document → reopen and search output.
2. **Image to print-ready design:** import image → crop/adjust/compose in Studio → set physical dimensions/DPI → preview → export → print handoff.
3. **Office file round-trip:** import supported DOCX/XLSX/PPTX/ODF → inspect unsupported content → edit supported content → export a new copy → reopen and compare expected content/fidelity.
4. **PDF workflow:** open existing PDF → render pages → search/select text where supported → reorder/rotate/extract/annotate as implemented → save a new file → reopen and verify.
5. **Stationery sale:** create/manage stock → basket with multiple sale lines → checkout → atomic stock movements and sale record → receipt → refund/void → ledger-backed reports.
6. **Cross-feature continuity:** scan, photo, design, office and print workflows all use the same file browser, asset references, export destinations, recovery patterns and visual language.

Every workflow needs automated unit/format fixtures plus device or platform integration tests. UI presence is not acceptance evidence.

## 7. Engineering order and gates

**Gate 0 — Truthful baseline:** reconcile docs and source, inspect all routes/screens/assets/dependencies, run formatting/analyzer/tests, inventory every implemented/partial/missing capability, and establish current CI/build state.

**Gate 1 — Consolidation:** canonical design tokens, app navigation, shared file/asset/project services, capability registry, one icon/branding catalogue, legacy-module boundaries and migration/recovery tests.

**Gate 2 — Core workflows:** make capture/OCR, Image Lab, creative editor, Office conversion and print production reliable end-to-end. Finish native camera/picker/lifecycle tests before claiming Android readiness.

**Gate 3 — Missing engines:** existing-PDF reader/page tools; richer office editing and compatibility via evaluated engines; advanced image tools; automatic page detection; transactional business ledger and complete POS. Implement in vertical slices with fixtures and explicit dependency/licence gates.

**Gate 4 — Release readiness:** backup/restore, database migrations, accessibility, localization, offline/low-memory/performance tests, privacy/security review, dependency notices, signed reproducible build, upgrade and install tests, desktop builds, and real printer/provider checks.

Do not skip ahead to new feature marketing while a core workflow fails its acceptance test. Do not install a new native engine merely because it is high-profile; first prove its capability, maintenance, licence, size, offline behaviour and target-device viability.

## 8. Current known limitations to keep visible

The repository's 2026-10-27 notes report host-tested scan/image/design/content-conversion foundations and offline OCR, but Android device behavior and release packaging remain unverified. Existing-PDF reading/manipulation, full layout-faithful Office editing, advanced Photoshop-class editing, complete transactional POS, full backup/restore, automatic edge detection and cross-platform packaging remain incomplete or unverified. Verify against current source and CI before changing these statuses.

**Definition of done:** a user can complete the advertised workflow with real inputs and outputs; data survives restart; source files are preserved; failure and cancellation are handled; outputs are reopened/validated; the feature uses shared design and engine services; automated tests pass; limitations and licences are documented; and target-device behavior is verified before release claims.


## Shared creative-imaging and template capabilities

The product-wide capability map now explicitly includes Photo & ID Studio, assisted/manual passport-style cropping, editable background removal, soft-copy and print-sheet outputs, and a searchable editable template catalogue for school/staff IDs, badges, business cards, posters/flyers, office documents and PowerPoint-style presentations. These are shared workflows, not isolated screens: they use the same project model, asset references, export/print pipeline, template schema and recovery rules.

Optional SLMs are a capability layer, not the product identity. Candidate runtimes must be benchmarked for Android memory/latency, licence, model size, offline behavior and native integration before selection. SLMs may suggest OCR corrections, classifications, layouts or crop guidance, but OCR, image segmentation, exact dimensions, accounting and exports remain real engines with reviewable results and deterministic fallbacks. Existing Tesseract remains the baseline OCR integration unless tests demonstrate a concrete reason to add another engine.

Implementation order: (1) audit current photo/print and template/project structures; (2) define a versioned editable template schema and starter pack; (3) deliver a tested ID-photo preset/crop/print-sheet workflow using the shared image pipeline; (4) benchmark background segmentation and add an editable-mask workflow only after device feasibility is proven; (5) evaluate one optional SLM runtime with feature flags and no-network core operation; (6) add ID/badge/card/poster/presentation template families through the same registry. Every stage requires tests, output reopen checks, licence/provenance records and Android-device profiling. This does not reduce priority of Office/PDF, Tesseract OCR, POS, asset consolidation or release readiness.
