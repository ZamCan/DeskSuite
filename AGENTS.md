# DeskSuite — Mandatory Product, Design & Engineering Instructions

> **Authority:** This file applies to the entire repository. Every human contributor, coding agent, automated agent, and future implementation task MUST read and follow it before inspecting, planning, editing, reviewing, or merging code. These requirements take precedence over generic agent defaults and superficial design requests. If a task conflicts with this directive, stop and explain the conflict rather than silently weakening product requirements.

## 1. Product identity and purpose

DeskSuite is a unified, professional, Android-first document production, scanning, PDF, office, image, creative-design, print-preparation, and print/stationery-business workspace. It is not merely a PDF reader, scanner wrapper, file browser, generic dashboard, or decorative UI prototype.

Build a coherent suite of real production tools. The product must feel like a carefully engineered professional application: fast, dependable, visually refined, understandable through direct interaction, and useful offline.

- Preserve the existing application identity, package identity, brand assets, working architecture, and user data.
- Offline-first and local-first are default architectural principles. Avoid paid APIs, mandatory accounts, Firebase/Supabase, cloud processing, and recurring infrastructure costs unless explicitly approved.
- Cloud services may be optional extensions, never hidden prerequisites for core local workflows.
- Do not market ordinary deterministic processing as AI. Do not add generic chatbot/agent interfaces or AI branding without explicit product approval.
- Never claim a capability that the current implementation does not genuinely provide.

## 2. Required product studios and real capabilities

Treat these as product capability requirements and audit the current repository before implementation. Do not assume every item is already implemented. Record what is complete, partial, missing, or technically unsupported. Implement honestly in stages; never simulate missing functionality.

### 2.1 Scanner Studio
Provide a real camera-based document workflow: camera preview and capture; permission and lifecycle handling; document-edge detection; manual corner adjustment; perspective correction; crop/rotate; image enhancement (colour, grayscale, black-and-white, contrast and shadow cleanup); multipage capture; reorder/delete; batch processing; OCR where supported; PDF and image export; save/share/print. Use appropriate native Android camera capabilities (such as CameraX through a maintained plugin or platform integration) where Flutter abstractions are insufficient. Handle resolution, orientation, focus, memory pressure, interrupted capture, and temporary files safely.

### 2.2 PDF Studio
Support genuine PDF opening and inspection, page navigation, combine/merge, split, reorder, rotate, delete/extract pages, images-to-PDF, pages-to-images, compression, metadata inspection, OCR, annotations, signatures, watermarks, page numbering, printing and sharing where supported. Preserve originals unless the user explicitly replaces them. Validate output files and report unsupported or lossy operations honestly.

### 2.3 Document Studio
Support document creation and editing with real text entry, formatting, headings, lists, tables, images, page setup, margins, import/export, PDF output, printing and sharing. DOCX compatibility must be based on an actual parser/writer or an explicitly integrated office engine. Do not present a read-only preview as full editing.

### 2.4 Office & Conversion Studio
Handle supported DOCX, XLSX, PPTX, PDF, TXT, CSV and image workflows through real format-aware engines. Preserve structure, formatting, formulas, slides, tables and metadata to the extent the selected engine supports them. Never convert by renaming an extension or presenting a flattened preview as an editable source file. Clearly disclose format limitations and conversion loss.

### 2.5 Photo Studio
Provide real image crop, resize, rotate, perspective adjustment, brightness, contrast, colour, background removal/replacement where a genuine implementation exists, image enhancement, batch processing and export. Include portrait/passport-photo preparation with configurable physical dimensions, background, output resolution and print-sheet layout. Keep originals safe and support undo/recovery where appropriate.

### 2.6 Creative Studio
Build an editable design workspace, not a single flattened image screen. Support configurable canvas sizes, templates, text and typography, image placement, layers, shapes, backgrounds, alignment, position, resize, transparency, colour, guides/grid, multipage designs, undo/redo, autosave and export to image/PDF/print-ready output. Persist project structure so users can reopen and edit projects.

### 2.7 Text & OCR Studio
Extract text from captured images, imported images and supported PDFs using genuine OCR. Provide language-aware recognition where available, text correction, selection, copy, save, search and export. Distinguish OCR from selectable text already present in a PDF. Explain unsupported languages and recognition uncertainty.

### 2.8 Print & Production Studio
Support A4/A3/A5 and custom page dimensions, portrait/landscape, margins, bleed/safe areas, print resolution, multiple images per sheet, passport-photo layouts, business-card sheets, print preview, printer handoff and export of production-ready files. Never imply that a file is print-ready unless its dimensions and resolution have been checked.

### 2.9 Business & POS Studio
Provide real local data workflows for products/services, inventory, stock movements, retail/wholesale prices, units, currencies, customers, suppliers, sales, purchases, receipts/invoices, expenses, profit, debts/payments and reports. Use persistent storage, transactional operations and accurate calculations. No static sample figures or fake sales dashboards.

## 3. Product experience and design direction

The visual quality must be premium, art-directed, coherent and native-feeling. Do not respond to design tasks by merely adding more cards, text, labels, instructions or gradients.

- Use a warm, professional neutral foundation with restrained, purposeful studio accents. Light and dark themes must both be deliberate and readable.
- Use glass-like/glassmorphic materials selectively: controlled translucency, subtle depth, refined borders and restrained blur. Do not blur every surface or sacrifice contrast.
- Use strong typography, disciplined spacing, clear hierarchy, carefully tuned radii, polished shadows, subtle motion and consistent design tokens.
- Avoid a dominant blue/dark-blue generic technology aesthetic. Avoid loud colour blocks, excessive gradients, visual clutter and decorative effects that weaken usability.
- Icons must be consistent, meaningful, recognisable and correctly placed. No random emoji, meaningless DS marks, or decorative brand marks used as filler.
- Use the authoritative DeskSuite logo and existing original studio artwork where present. Inspect assets before replacing them. Do not replace purposeful illustrations with generic icons without a clear reason.
- Avoid generic web-dashboard appearance. Build a responsive application experience that feels designed for phones first and scales naturally to tablets and desktop.
- Do not overload screens with explanatory paragraphs, tutorial wording, marketing slogans or repeated labels. Prefer concise names, visual cues, clear actions, and progressive disclosure.
- Design must serve real tasks and content. Every visible component should have a clear purpose.

## 4. Home, navigation and onboarding

The home screen is a professional production workspace, not a generic collection of decorative cards.

- Establish clear brand/workspace identity and a strong visual hierarchy.
- Make primary production actions—especially scanning and document creation—easy to discover and reach.
- Organise studio destinations coherently; provide useful search across actual tools and, where implemented, real local files/projects.
- Show recent work only from genuine persisted user data. Do not invent recent files, projects, metrics, templates-in-use or activity.
- Keep navigation predictable, responsive and consistent. Every destination must exist and work.
- On first launch, provide a polished, concise onboarding flow with clear Continue, skip-step and skip-all choices. Use visual demonstrations and short explanations, not long instruction pages.
- Never add example documents, fake projects, demo buttons or placeholder workflows to make an unfinished screen look populated.
- Empty states should explain the next useful action briefly and provide a real action.

## 5. Flutter architecture and implementation standards

Work with the repository's actual Flutter/Dart architecture. Audit before refactoring. Prefer feature-oriented separation of presentation, application/domain logic and data access, with clear boundaries and reusable design primitives.

- Follow the existing supported Flutter/Dart versions, dependency constraints, lint rules and established state-management/navigation patterns unless a documented technical reason justifies a change.
- Use strong typing, clear models, predictable state transitions, dependency injection where appropriate, and testable business logic.
- Keep widgets focused. Do not put complex document processing, file I/O, database logic or image transformations inside build methods.
- Use isolates/background execution for CPU-heavy operations where appropriate. Avoid blocking the UI thread.
- Use native Android integrations/platform channels when required for camera, document providers, printing, media processing or other platform capabilities. Keep platform boundaries explicit and testable.
- Choose maintained dependencies based on licence, compatibility, security, maintenance, offline behaviour, binary size and real capability. Do not add packages speculatively.
- Do not introduce mandatory remote services, API keys, paid SDKs or hidden subscriptions without explicit approval.
- Maintain responsive layouts, dynamic text scaling, accessibility semantics, keyboard support where relevant, adequate touch targets, contrast and orientation handling.

## 6. Data, files and reliability

- Persist user projects, documents and business data reliably. Use transactions for multi-step database changes.
- Protect source files; write to a new output or temporary location and validate before replacing anything.
- Handle Android scoped storage, content URIs, document-provider access, permissions, cancellation and interrupted operations correctly.
- Use safe temporary-file lifecycle management, cleanup, cache limits, integrity checks, backup/restore and recovery paths.
- Avoid loading unnecessarily large images/PDFs fully into memory. Use streaming, thumbnails, paging and bounded processing where practical.
- Autosave editable work where appropriate. Communicate save state accurately and protect unsaved changes.
- Provide meaningful loading, empty, success and error states. Errors must be actionable and must not silently discard user data.
- Destructive actions require clear confirmation and, where feasible, undo or recovery.

## 7. Interaction and capability honesty

Every visible control must perform its advertised action. No dead buttons, decorative controls that look interactive, fake progress, placeholder navigation, simulated output or success messages before an operation has actually succeeded.

For every feature, verify the full workflow: entry point, user input, validation, processing, persistence, output, error/cancel behaviour and reopening/reuse. If a capability is not implemented, hide it or mark it clearly as unavailable/in development; do not disguise it as complete.

## 8. Repository and agent workflow — mandatory

Before changing code:

1. Read this file and inspect the repository structure, README/docs, pubspec, analysis/lint configuration, tests, assets, navigation, theme/design system and relevant feature implementations.
2. Inspect the current main state and relevant open branches/PRs. Understand existing work and user-facing behaviour.
3. Identify working functionality and preserve it. Do not rewrite or duplicate an existing engine merely because a new implementation is easier to generate.
4. Produce a concise audit: existing/working, partial, missing, defects, dependencies and proposed safe changes.
5. Define the scope and acceptance criteria for the task before implementation.

During implementation:

- Make small, coherent, reviewable changes. Reuse established architecture and components.
- Avoid broad unrelated refactors, dependency churn and unnecessary file renames.
- Preserve package/application identifiers, signing configuration, user data and database compatibility unless the user explicitly authorises a change.
- For schema changes, provide a migration and test existing data compatibility.
- Do not remove, overwrite or replace user assets or working modules without inspection and a justified migration path.
- Keep documentation aligned with actual behaviour.

Before merging:

- Run formatter, static analysis, relevant unit/widget/integration tests, navigation and persistence tests, and Android debug/release build checks appropriate to the change.
- Test realistic inputs and failure paths, not only empty/demo data.
- Verify that generated documents/images/PDFs open correctly and that files are not corrupted.
- Review the diff for accidental deletions, duplicated features, fake controls, hard-coded demo data, security/privacy issues and regressions.
- Report exact commands and outcomes. Never claim tests, builds, installation or device verification that were not actually performed.
- Merge to main only after required checks pass and conflicts are resolved. Do not force-push or bypass protections.

## 9. Quality gates and definition of done

A feature is not complete merely because its screen looks attractive or the project compiles. It is complete only when all applicable conditions are met:

- The UI is polished, coherent, responsive and accessible.
- The underlying engine performs the real advertised operation.
- Inputs are validated and realistic files/data are handled.
- Results are correct, persistent when required, and reopenable.
- Errors, cancellation, permissions and destructive actions are handled safely.
- Navigation and every visible control work.
- Performance and memory use are appropriate for Android phones.
- Relevant tests pass, and platform/build checks are reported truthfully.
- Documentation and capability claims match the shipped implementation.

## 10. Delivery priorities

Use these priorities when planning the product, while respecting existing working code and dependencies:

1. Stabilise the foundation: architecture, design system, navigation, persistence, file handling, startup and diagnostics.
2. Deliver dependable core production workflows: Scanner Studio, PDF Studio and Document Studio.
3. Deliver image and creative production: Photo Studio, Creative Studio, OCR and print preparation.
4. Deliver real office-format workflows and Business/POS functionality.
5. Harden cross-platform support, performance, accessibility, backup/recovery, release signing and production readiness.

Do not pretend all studios are complete at once. Prefer fewer fully working professional workflows over many shallow screens.

## 11. Required agent response format

At the start of a substantial task, state briefly:
- what repository areas and existing functionality were inspected;
- what is already working and what is missing;
- the exact implementation scope and acceptance criteria.

At completion, report:
- files/modules changed and why;
- real user-visible behaviour delivered;
- tests/builds actually run and their exact outcomes;
- known limitations or unfinished work;
- branch/commit/PR/merge status.

**Final instruction:** Build DeskSuite as a genuine professional production suite. Do not optimise for the appearance of progress. Do not replace engineering with wording, cards, mockups or promises. Inspect first, preserve what works, implement the real capability, test it, and report honestly.
