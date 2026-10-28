# Roadmap and release gates

## Implemented and host-tested

- [x] Integrated live studios into the current main workspace while preserving existing settings, project roots and earlier data paths.
- [x] Physically dimensioned editable design, text/shapes/images, arrangement, history, save/reopen, copy import/export, PNG and raster PDF.
- [x] Non-destructive earlier project conversion and interrupted-replacement recovery.
- [x] Local photo transformations, exact pixel dimensions, actual encoded-output review and configurable one-page photo-sheet PDF.
- [x] Manual projective page correction, ordered multipage image PDF, bounded private scan draft and failure/retry coverage on the host.
- [x] Skippable, revisitable sample guides and explicit conversion catalogue linking to real tools.
- [x] Notes save/error/retry and TXT export; starter catalogue/stock counters, exact minor units and JSON export.
- [x] PDF physical-size and fake print-gateway behavior; baseline sequential host suite and targeted later tests. The source status recorded on 2026-10-27 reports 152 passing sequential host tests, clean analysis and formatting. Re-run the complete suite after subsequent changes; Android and release gates remain separate.

## Implemented, not fully validated

- [ ] Local uneven-lighting / adaptive B&W document previews and selective photo-speck reduction, with realistic synthetic examples. Pixel cores passed a DDC/Node smoke check; Flutter codec, widget, integration and Android tests are still pending.
- [ ] Native Android camera capture/recovery, file picking, saving, lifecycle/process death, actual printer discovery/output, adaptive icons/splash and accessibility on representative devices.
- [ ] Checked-in Android scaffold and external release-signing configuration: no integrated APK/AAB or device upgrade was built/tested in this execution.
- [ ] Windows/Linux/iOS plugins, generated desktop runners, packaging and OS-specific paths.
- [ ] System print scaling, colour, real margins and ID-photo requirements.

## Implemented in this source (2026-10-27)

- **Offline OCR** for English and English+Kiswahili with Tesseract 5 through
  Tesseract4Android; editable review, low-confidence warning, TXT and DOCX
  export, and a searchable PDF whose invisible text layer is verified in tests.
- **Office reading and conversion**: DOCX, XLSX, PPTX, ODT, ODS, ODP, RTF, TXT
  and HTML → PDF, TXT, CSV, ODT or ODS, with per-route fidelity and limits, a
  bounded package reader and an optional LibreOffice seam. See
  [office support](engineering/OFFICE_SUPPORT.md).
- PDF output now embeds a Unicode font so accents, dashes and smart quotes are
  not dropped.
- `flutter test` 152 passing; `flutter analyze` clean.

## Not implemented / next slices

- [ ] Full suite backup, restore, migrations and cross-ID import for notes/catalogue, with crash and storage-full tests.
- [ ] Transactional multi-instance database; complete POS, payment/refunds, sale lines, receipts, expense/profit reports and audit history.
- [ ] Validate OCR accuracy/language behavior on representative real documents and Android devices; automatic page-edge detection with manual fallback.
- [x] PDF Studio entry point and supported existing-PDF edit/save-as-copy flow are integrated on the consolidation branch; full CI, lockfile and device validation are pending.
- [ ] Robust PDF text search/extraction, page reorder/rotate/extract/merge, guaranteed structural compression, encrypted export and accessible preview.
- [ ] Rich document editor, spreadsheet/formulas, presentation editing and stronger DOCX/XLSX/PPTX interoperability, based on tested format engines and explicit fidelity boundaries.
- [ ] Advanced image editing: arbitrary crop/selection, non-destructive layers/masks, richer adjustments and optional local segmentation; no model downloads without consent.
- [ ] Guides/snapping, professional vector/SVG tools, colour management, bleed/crop marks, imposition and printer calibration.
- [ ] Consolidated asset registry with provenance/licences, reference tracking, thumbnails, deduplication and safe migration.
- [ ] Complete transactional stationery POS: sale lines, stock ledger, refunds/voids, suppliers, expenses, customer balances, audit trail and ledger-backed profit reports.
- [ ] Validate PDF Studio against independent readers and protected/malformed fixtures; verify memory/performance and save/reopen on actual Android and desktop devices. Extend page tools and encryption only through tested, compatible engines.
- [ ] Full accessibility, localization, dark theme across the restored studios, performance and low-memory profiling.

## Release gate: **not passed**

Require a signed, reproducible Android release with stable package ID and key custody; real-device cold/offline/upgrade/process-death/storage-full tests; native file-picker and printer checks; verified backup/restore; dependency/licence and permissions review; accessibility/performance testing; and a reviewed CI run/artifact. A host test pass or a debug APK is not equivalent to these gates.


## Creative imaging, ID photography and template expansion

- [ ] Audit the existing Photo Studio, photo-sheet, project serialization, template/sample assets and export/print services before adding another engine.
- [ ] Build a shared editable template registry/schema with licence/provenance metadata, preview thumbnails, stable IDs and versioning.
- [ ] Add configurable ID/passport-style presets (authority-specific where verified), assisted and manual crop/pose guidance, background presets, output review, exact physical sizing and multi-photo print sheets. Do not claim official acceptance.
- [ ] Evaluate local background segmentation models versus classical methods; benchmark hair edges, transparent objects, memory, latency, licences and offline operation before selecting one shared implementation.
- [ ] Add editable school/staff IDs, visitor/event badges, business cards, posters/flyers and presentation themes/layouts through the shared catalogue rather than flattened images.
- [ ] Benchmark one optional SLM runtime behind a capability interface for reviewed OCR-correction/layout suggestions only; keep Tesseract OCR and deterministic processing as real engines and ensure core workflows work without model downloads or network access.
- [ ] Add fixture-based tests for dimensions, aspect ratios, masks/transparency, template save/reopen, print-sheet layout, missing model, cancellation and low-memory failure; verify on modest Android hardware.


## Latest source change — Photo Studio background placement (2026-10-28)

- [x] Solid-colour compositing for images that already contain transparency, with a manual colour picker, bounded shared processing, PNG output and unit-test coverage added.
- [x] Editable photo-sheet size examples and custom physical dimensions.
- [ ] Actual background removal / segmentation, editable masks and edge refinement.
- [ ] Guided ID-photo crop, head/shoulder framing and verified authority-specific presets.
- [ ] Shared editable template catalogue for school/staff IDs, badges, business cards, posters/flyers and presentation themes.
- [ ] Optional SLM capability adapter and measured local-runtime selection.
- [ ] Run format, analyzer, all Flutter tests and Android build/device checks after this slice; do not mark as passed until actual results are recorded.

## 2026-10-28 — shared editable starter templates

- [x] Add one stable-ID template registry and wire it into the existing new-design dialog and shared editable project model.
- [x] Add starter layouts for blank, editorial poster, business card, identity badge, certificate, flyer and presentation cover.
- [x] Add source-level tests for catalog identity, element bounds, serialization round-trip and the template-selection UI.
- [ ] Expand the registry with reviewed, licensed template packs, image/logo placeholders and editable photo frames; do not imply that a starter badge is an official ID specification.
- [ ] Add multi-slide presentation documents and real PPTX import/export through the Office capability registry; the current presentation-cover template is a single editable design page, not a PowerPoint deck.
- [ ] Run the new tests, formatter, analyzer, complete Flutter suite and Android/device checks before marking verification complete.

- [x] Record starter-template schema version, source/provenance and repository licence metadata; validate canvas dimensions and keep generated objects within custom canvas bounds.
- [ ] Add human-reviewed previews, true image/photo placeholders and a user-editable template library; metadata alone is not a substitute for licence review of future third-party packs.



## 2026-10-28 — photo print-sheet starter layout

- [x] Add an A4 photo print-sheet starter to the shared template registry, with twenty bounded editable 35 × 45 mm example slots and explicit print-scaling caveat.
- [x] Test the slot count, editable object types and shared canvas geometry at source level.
- [ ] Replace generic shape placeholders with actual image-frame/drop-in asset support before calling this a photo imposition workflow; validate output on real printers and verify any authority-specific dimensions separately.
- [ ] Run formatter, analyzer, complete Flutter suite and Android/device checks; no passing result is claimed until CI reports it.


## Photo print-sheet interaction (2026-10-28)

- [x] Add an editor action to fill a selected 35 × 45 mm catalogue slot with a locally picked image; replace the placeholder and label in one undoable edit.
- [x] Route the image through the existing embedded-image project format and shared renderer/export path, with cover fitting to the physical slot.
- [x] Add controller tests for replacement, encode/decode, undo and rejection of a normal rectangle.
- [ ] Confirm tests/analyzer/formatting in CI, then test actual Android picking and real print scaling. This is manual slot placement, not automatic multi-photo batching, face alignment or certified ID-photo processing.


## 2026-10-28 — print-production specification gate

- [x] Document a production model separating finished product, source sheet/roll, substrate, device profile and authority requirements.
- [x] Start Photo Sheet with 4 × 6 inch media as a convenient small-format option; retain A4/A5/custom as independent choices.
- [x] Rename the A4 photo layout example so it is not presented as a passport preset; leave Tanzania passport dimensions unspecified when the cited source does not publish them.
- [x] Record the scope of ISO 216, ISO/IEC 23385, ICAO Doc 9303 and ISO/IEC 7810 in `docs/engineering/PRINT_PRODUCTION_STANDARDS.md`.
- [ ] Add A3, B-series, US Letter/Tabloid and roll-media profiles only where the output path/device supports them.
- [ ] Implement printer/media capability profiles, trim/bleed/safe areas, actual-size controls and export validation.
- [ ] Verify physical dimensions, colour/quality and media compatibility on actual supported devices before claiming production readiness.


## 2026-10-28 — complete media and engine integration gate

- [x] Expand the photo-sheet sheet-media selector from small photo paper to ISO A/B formats, US letter/legal/tabloid/ledger, photo prints, and poster/large-format presets; allow custom media up to 2500 mm per side.
- [ ] Use one shared paper/media catalogue across photo sheets, new-design canvas, documents, badges and poster exports; distinguish stock/sheet size from finished photo/card size and from printer-supported media.
- [ ] Add envelope/C-series, card/badge, label, roll-media and device/printer capability profiles; show unsupported media or clipping risks before printing.
- [ ] Make large-format export resolution aware of page dimensions and the output pixel budget; offer validated lower DPI when needed rather than pretending every poster can render at 300 DPI on every device.
- [ ] Maintain the engine/package register in [ENGINE_INTEGRATION_REGISTER.md](engineering/ENGINE_INTEGRATION_REGISTER.md); integrate only reviewed dependencies with pinned versions, notices, real fixtures, and measured device behavior.
- [ ] Verify the existing offline Tesseract integration end-to-end on Android with English and Kiswahili. Do not confuse OCR with an SLM; evaluate an optional SLM runtime only after ABI, licence, model size, RAM/latency, privacy and offline tests.
- [ ] Finish the complete CI matrix, repair every analyzer/test/build regression, and run APK install/upgrade/offline/storage/printing/OCR/photo/design/office tests on the actual target phone before calling the product build-ready.
