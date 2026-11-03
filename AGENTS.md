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


---

# 12. CREATIVE ENGINEERING EXPANSION — MANDATORY PRODUCT DIRECTION

This section extends and clarifies the product requirements above. It does not authorize replacing existing working modules, duplicating engines, changing the app identity, or claiming capabilities that have not been implemented and tested.

## 12.1 Product outcome

DeskSuite must grow into a serious **offline professional productivity and creative-production suite**. Its creative capabilities should be benchmarked against the kinds of work people perform with Photoshop, Illustrator, Animate and After Effects, while retaining an original DeskSuite identity, Android-first ergonomics, bounded resource use and local ownership of files.

These are capability references only. Do not copy Adobe source code, proprietary assets, interface layouts, trademarks or undocumented formats. Do not claim Adobe equivalence or full feature parity. Build the specific workflows below as genuine, testable DeskSuite capabilities.

The product has two connected pillars:

- **Office & Production:** documents, spreadsheets, presentations, scanning, OCR, PDF, files, printing and stationery-business workflows.
- **Creative & Graphics:** photo manipulation, vector illustration, graphic composition, print artwork, 2D animation and short motion-graphics production.

They remain one application with one workspace, shared assets, projects, import/export, typography, colour, file identity, undo/recovery conventions and design system. Do not create disconnected mini-apps or duplicate editors.

## 12.2 Creative workspaces and intended capability

### A. Photo Studio — advanced raster/photo editing

Evolve the existing Photo Studio and shared image pipeline; do not create a competing image editor.

Target capabilities, implemented in verified stages:

- Non-destructive adjustment stack with enable/disable, reorder, edit and reset.
- Crop, rotate, flip, straighten, perspective correction, resize, resample and canvas-size controls.
- Selection tools and editable masks; brush, eraser and mask refinement.
- Layers and groups with visibility, opacity, blend modes, ordering, lock and rename.
- Pixel brush engine with configurable size, hardness, opacity, spacing and supported brush presets.
- Healing/clone tools only when a real sampling/retouch implementation exists.
- Exposure, brightness, contrast, highlights, shadows, levels/curves where feasible, white balance, saturation, vibrance, hue, temperature, tint, grayscale and colour controls.
- Blur, sharpen, noise reduction, edge, vignette, shadow, glow and other effects with bounded previews and documented limitations.
- Background removal only through a genuine local segmentation/matting implementation or explicit manual selection/masking. A white/solid fill, transparency compositing or edge heuristic must never be labelled automatic background removal.
- Alpha/transparency handling, compositing, clipping/masks and export to PNG, JPEG, WebP and other genuinely supported formats.
- Before/after comparison, undo/redo, checkpoints, autosave/recovery and preservation of the untouched source.

Do not load full-resolution originals repeatedly for every slider movement. Use proxy previews, tiled/region processing, isolates/native workers and a memory budget. Final export must render from the original-resolution source and full edit graph where supported.

### B. Vector Design Studio — Illustrator-inspired vector work

Build vector editing as a genuine object/path model, integrated with the existing Creative Studio document model where technically sound.

Target capabilities:

- Editable paths, nodes/anchors, Bézier handles, pen and node editing.
- Lines, polygons, rectangles, ellipses, stars and custom paths.
- Fill, stroke, width, cap, join, dash, gradients and opacity.
- Object selection, multi-selection, grouping, alignment, distribution, transforms, snapping, guides and grids.
- Boolean path operations only when geometrically correct and tested.
- Editable text objects with font family, size, weight, tracking, line height, alignment, paragraph settings and text-on-path only when supported.
- SVG import/export that preserves supported paths, text, gradients and transforms; report unsupported SVG features rather than silently flattening.
- High-resolution raster and PDF export through the same geometry and colour model used by the editor.

Do not describe raster images placed on a canvas as vector artwork. Do not flatten vector objects when saving an editable project.

### C. Graphic Composition Studio — professional design and layout

Extend the current editable Creative Studio, not a duplicate replacement. Support posters, flyers, advertisements, banners, invitations, certificates, menus, business cards, labels, social graphics, brochures and print layouts.

The editor must progressively support:

- Physical and pixel canvas sizes, orientation, bleed, safe area, margins, guides and print DPI.
- Editable text, images, vector shapes, paths, groups and reusable components.
- Layer ordering, alignment, distribution, snapping, rulers, grids, constraints and precise numeric transforms.
- Image crop/fill/fit, opacity, masks, borders, shadows and effects.
- Rich typography and multi-style text only where the text engine truly supports it.
- Multi-page documents and reusable local templates.
- Consistent colour profiles/colour handling where supported; do not claim print colour calibration without device/profile tests.
- Project save/reopen without flattening; PNG/JPEG/WebP/SVG/PDF export according to supported object types.
- Print-ready validation for page geometry, bleed, safe area, effective resolution and embedded/available fonts.

Template previews are not finished designs and must remain editable. Do not fill the product with fake templates, example projects or decorative demo content.

### D. Motion Graphics Studio — short-form graphics, not a general video editor

Build a focused composition and animation engine for graphic-led outputs such as television/channel intros, logo reveals, animated titles, short advertisements, animated posters, lower thirds, bumpers, transitions, kinetic typography and simple 2D scene animation.

This is deliberately **not** a Premiere Pro-style non-linear video editor. Do not add general-purpose footage editing, multi-camera editing, complex audio post-production or a full media timeline for arbitrary source videos.

Target capabilities:

- A scene/composition with explicit dimensions, frame rate, duration and background.
- Timeline tracks for supported text, vector, image, shape, group and effect objects.
- Keyframes for position, scale, rotation, opacity, colour and supported effect parameters.
- Interpolation/easing, timing controls, object in/out points, trim, stagger and sequencing.
- Animated typography, shape transforms, logo reveals, masks and transitions.
- 2D camera/pan/zoom/parallax only where the scene renderer supports it.
- Particle, glow, light, blur and other GPU effects only when bounded, cancellable and measured on representative Android devices.
- Optional local audio track for simple timing/synchronization if codec and lifecycle support are verified; do not let audio become a dependency for graphics-only projects.
- Real-time or proxy preview with honest dropped-frame/quality indicators.
- Deterministic offline frame rendering and actual MP4 export through a verified Android encoder (for example, MediaCodec) or a tested cross-platform adapter.
- Export presets for dimensions, frame rate, duration and bitrate, with output inspection and playback verification.

A timeline UI without a real render pipeline is not an implementation. A sequence of static screenshots is not motion graphics. Do not claim After Effects parity.

### E. 2D Animation Studio

Support a focused 2D animation workflow sharing vector, raster, composition and timeline primitives:

- Frame-by-frame animation with editable frames and onion-skin preview.
- Keyframe/tween animation for supported vector and transform properties.
- Scene/stage, layers, frame duration and playback controls.
- Reusable symbols/objects only if their instances preserve correct edit semantics.
- Export to GIF/APNG/MP4 or image sequence only when each encoder is implemented and tested.

Character rigging, facial capture, lip sync and advanced puppet deformation are future optional capabilities, not assumptions. Do not claim Character Animator parity.

## 12.3 Shared creative document and rendering architecture

Before introducing a new engine or dependency, inspect the existing Creative Studio model, image processing code, project serialization, PDF/print rendering and file services. Extend or adapt them through stable interfaces. Do not create parallel raster/vector/scene models without a written migration and interoperability reason.

The architecture should converge on:

1. **Project/document model:** versioned editable document with canvas/page/scene dimensions, units, background, objects, z-order, transforms, styles, tracks, keyframes and metadata.
2. **Asset registry:** stable local asset IDs, source/original reference, MIME type, dimensions, byte size, hash, thumbnail, provenance/licence and reference count. Avoid duplicating large images into every project.
3. **Object model:** typed text, raster image, vector path, shape, group and supported effect objects with explicit serialization.
4. **Edit command/history model:** undo/redo commands or immutable edit operations; avoid storing full image copies for every action.
5. **Renderer interfaces:** screen preview, high-resolution raster, SVG and PDF rendering must share the same object semantics where possible. Motion rendering uses the same object model plus time/frame evaluation.
6. **Operation service:** validate → estimate resources → process → report measurable progress → cancel safely → validate output → atomically save → publish a stable file reference.
7. **Versioned serialization:** migrations for existing .dsdesign projects and any other persisted formats. Never break or silently rewrite existing user projects.

Evaluate Skia/Flutter Canvas, Impeller, shader support, native Android graphics, OpenCV, image codecs, SVG libraries and media encoders against actual requirements. These are candidates, not automatic endorsements. Measure rendering correctness, licence, maintenance, Android ABI, APK size, memory, latency, thermal behaviour and offline availability before adoption. Do not assume Flutter's renderer supplies a complete Photoshop, Illustrator or After Effects engine.

## 12.4 Android-first, offline and resource constraints

- Core editing, project persistence, rendering and exports must work without network access.
- Do not require account creation, cloud processing, paid APIs, subscriptions or online model downloads for core features.
- Optional local ML models must be bundled or explicitly imported by the user, licence-reviewed, versioned, size-disclosed and disabled until needed. Prefer deterministic/manual tools when they give reliable results at lower cost.
- Target ordinary Android phones, including devices with approximately 4–8 GB RAM. Treat this as a performance design constraint, not a promise that every advanced effect fits every device.
- Decode images with dimension/byte limits, use thumbnails and proxy previews, tile large canvases, bound caches and process expensive work off the UI thread.
- Check memory before high-resolution render; provide a clear lower-resolution/proxy option when a device cannot safely complete the requested output.
- Keep expensive engines unloaded until the user enters the relevant workspace or invokes the feature. Release GPU/native resources when leaving or cancelling.
- Support touch-first manipulation, precise numeric entry, stylus where available, keyboard/mouse on larger platforms and accessible controls.
- Measure cold start, APK size, preview latency, export time, peak memory, frame stability, cancellation and thermal impact on real devices before describing performance as production-ready.

## 12.5 Creative UI/UX quality contract

Creative workspaces must feel like professional instruments, not forms or web dashboards.

- Give the canvas/image/scene the dominant visual space.
- Use compact contextual toolbars and property panels that change with the selected object/tool.
- Put frequent actions within comfortable phone reach; reveal advanced controls progressively.
- Use purposeful glass-like surfaces selectively, controlled blur, fine borders and clear contrast.
- Follow the current DeskSuite visual identity and the governing visual/product directives. Use the restrained ice-blue signature accent only in the established role; do not turn the entire app blue or introduce an unrelated palette.
- Maintain deliberate light and dark themes, legible typography, consistent iconography, clear selection/focus states and accessible touch targets.
- Do not use emoji as product icons, meaningless DS marks, random gradients, excessive cards, oversized text instructions or marketing copy inside the editor.
- Avoid duplicating the same toolbar, navigation, save action or property in multiple places.
- Provide useful gestures: pan, pinch zoom, selection, drag, rotate and resize, with numeric precision alternatives and undo.
- Every control must change the actual project state or perform its labelled operation. No decorative fake sliders, simulated export, dead tool icons or success messages before output validation.

## 12.6 Interoperability and cross-workspace workflows

Prioritize coherent handoffs using stable file/asset/project references:

- Files → Photo Studio → Creative Studio.
- Photo Studio → Creative Studio and print production.
- Creative Studio → PDF/Print and image export.
- Vector Design → Creative Studio composition and SVG/PDF export.
- Creative Studio objects → Motion Graphics scene.
- Motion Graphics → verified MP4/GIF/image-sequence export.
- Scanner/OCR/PDF/Office assets → Creative Studio when the source format can be represented honestly.

Preserve original sources. Make handoffs copy-on-edit or explicitly versioned; do not mutate a source file unexpectedly. Report when a format must be rasterized or loses editability.

## 12.7 Engineering sequence and acceptance gates

Implement in this dependency order, adapting to the actual source audit:

1. Stabilize the existing project/file/asset model, versioned .dsdesign serialization, history, autosave and shared renderer contracts.
2. Improve the existing raster image pipeline and Photo Studio with real non-destructive adjustments, selections/masks and layers.
3. Extend the existing Creative Studio with precise composition, vector paths, typography and reusable editable objects.
4. Add vector import/export and high-resolution print/render validation.
5. Build a shared timeline/frame evaluation model and basic 2D motion composition.
6. Add verified offline frame rendering and MP4/GIF export.
7. Expand animation tools and advanced effects only after performance and reliability gates pass.

For every milestone, add unit tests for model/geometry/serialization/history; golden or pixel-diff tests for rendering; fixture tests for import/export; widget tests for real interaction; integration tests for save/reopen/handoff; and Android device tests for memory, lifecycle, GPU/codec and export. Validate output with independent decoders/viewers. Include malformed, oversized, transparent, high-resolution and interrupted-operation cases.

Do not attempt all five engines in one rewrite. Prefer one shared foundation and a few complete workflows over many shallow controls.

## 12.8 Creative feature truth matrix

For each creative capability, keep an implementation truth table in the relevant engineering status document. Use only these states: **Implemented and tested**, **Implemented but not fully verified**, **Partial**, **Planned**, or **Unsupported**.

At minimum track raster layers/groups; selections/masks; brush/eraser; non-destructive adjustments; clone/healing; background segmentation; vector paths/node editing; SVG import/export fidelity; rich typography; multi-page composition; high-resolution raster/PDF export; timeline/keyframe interpolation; motion preview; MP4/GIF encoding; offline operation/model availability; low-memory fallback/cancellation; and editable-project round-trip/migration.

The feature menu, onboarding, README, release notes and in-app labels must never claim a higher state than the evidence. A partial manual workflow must not be presented as automatic processing. A rasterized export must not be described as editable vector output. A generated short graphic animation must not be described as full video editing.

---

# 13. MANDATORY FIRST 20-MINUTE ENGINEERING SPRINT

When an agent is asked to continue DeskSuite development, it must perform a focused, implementation-led first 20 minutes on the latest main state. This is a time-boxed execution protocol, not permission to rush unsafe changes or claim work that was not completed. If the environment does not expose a reliable clock, follow the ordered work budget below and report it as a planned 20-minute sprint rather than inventing elapsed time.

### Minute 0–3 — refresh and inspect
- Fetch latest main, inspect working tree/branch and recent commits; do not overwrite concurrent work.
- Read this AGENTS.md, CURRENT_STATUS.md, MASTER_PRODUCT_ENGINEERING_PLAN.md, UNIFIED_PRODUCT_ARCHITECTURE.md and the relevant roadmap.
- Inspect the actual target screen, service, model, tests and assets before editing.
- Identify one existing user-visible feature that can be improved safely without creating a duplicate module.

### Minute 3–6 — establish evidence and scope
- Run the narrowest relevant existing test/analyzer command if the environment permits.
- Record the current behaviour, code locations, known defect or missing capability and a measurable acceptance criterion.
- Choose a vertical slice that can be completed and verified in the time box. Prefer improving an existing Photo Studio, Creative Studio, image pipeline, project persistence, export or shared interaction over adding a new menu item.

### Minute 6–15 — implement a real improvement
- Make a small coherent code change in the existing architecture.
- Prioritize correctness, usability, project/data preservation and actual engine behaviour.
- Examples: fix a broken existing interaction; improve an existing crop/resize/colour operation; add a tested layer/object property; harden .dsdesign save/reopen; improve undo/redo; validate export dimensions; correct a real layout issue; improve cancellation or memory bounds.
- Do not spend the sprint only writing plans, adding empty classes, installing speculative packages, creating placeholder screens or renaming folders.
- Do not implement a fake Adobe-like tool merely to make the interface look richer.
- If no safe implementation can be made because the baseline is broken or access is read-only, make the smallest useful diagnostic/test/documentation correction and explain the blocker.

### Minute 15–18 — verify and harden
- Format changed Dart files.
- Run focused tests and static analysis available in the environment.
- Inspect the diff for unrelated changes, source-file overwrite risks, project migration gaps, dead controls and inaccurate capability claims.
- Reopen/round-trip relevant project or output fixtures when applicable.
- Fix any regression discovered; do not suppress a failing test to create a green result.

### Minute 18–20 — record and hand off
- Update the relevant status/roadmap only with verified facts.
- Record files changed, behaviour improved, tests actually run, limitations and exact next step.
- Commit only if repository permissions and workflow allow it, the diff is coherent, and checks pass. Never force-push, bypass protections or claim a merge that did not happen.
- If the 20-minute slice reveals a larger issue, create a precise follow-up task with reproduction steps and acceptance criteria rather than beginning an uncontrolled rewrite.

### Sprint completion standard

The sprint must leave at least one concrete improvement to existing functionality or one verified defect diagnosis with a reproducible test. A new screen, attractive mockup, plan-only document or list of future ideas does not count as engineering progress. The 20-minute sprint is the first focused increment; continue with subsequent bounded increments when the task and available execution time permit.

**Creative product directive:** Build the actual editing, compositing, vector, animation and rendering capabilities into the existing DeskSuite architecture. Preserve what already works, improve existing features first, keep the APK offline and resource-aware, and prove every new capability with tests and real output files.
