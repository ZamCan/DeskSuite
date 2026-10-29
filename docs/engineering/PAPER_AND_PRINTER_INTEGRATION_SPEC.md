# DeskSuite — Paper and Printer Integration Specification

**Status:** Engineering contract; implementation and device validation still required.  
**Scope:** Android-first shared media sizing, scan-to-print continuity, printer capability discovery and repeatable print profiles.

## Objective

Paper sizing is a shared system service, not a manually duplicated dropdown. A user should capture or open a document once, then carry the correct physical dimensions, orientation and output intent through cleanup, OCR, PDF assembly, image/design work and printing. Recommendations must be automatic where evidence is available, transparent where it is not, and always reversible.

## Canonical data model

Maintain one canonical registry of media definitions. Each definition should have a stable ID, display label, width and height in millimetres, family (ISO A/B/C, US/ANSI, photo, card/badge, label, envelope, poster/large-format, custom), and relevant constraints/notes. Store dimensions in one canonical unit (millimetres); convert at explicit boundaries only.

Keep these separate:

1. **Source geometry:** detected or declared dimensions of the imported page/image, including EXIF orientation where relevant.
2. **Intended output media:** the physical sheet/roll/canvas requested by the user.
3. **Finished item geometry:** photo, badge, label or artwork size placed on that sheet.
4. **Raster quality:** pixel dimensions, effective DPI at final physical size, color/alpha characteristics and memory budget.
5. **Printer capabilities:** capabilities actually reported by the selected Android print service/driver. A catalog entry is never evidence of hardware support.
6. **Job policy:** fit, fill/crop, actual-size/100%, or user-confirmed stretch; margins, bleed, crop marks, imposition, copies, orientation and any available color/duplex/media preferences.

Do not collapse these into one paper-size string or infer printer support from a selected preset.

## Automatic synchronization contract

- Scan Studio records source geometry and orientation in document/page metadata. It must not overwrite source dimensions merely because a recommended print preset is selected.
- PDF page setup, photo sheets, design canvas/export, office-document preparation and print preparation consume the same registry/service; no screen owns a parallel standards list.
- When an output destination changes, recompute dependent preview, printable area, scaling, effective DPI, pagination/imposition and warnings from the same job model.
- Preserve a user's custom size as a validated profile rather than silently rounding it to a nearby standard. Custom dimensions must respect renderer and target-driver limits.
- When dimensions are detected, recommend a likely standard only within a documented tolerance and show the recommendation's reason. Ambiguous/rotated/cropped sources must not be confidently mislabeled.
- Reopening a job restores its chosen output intent and last valid settings, while rechecking live printer capabilities before dispatch.

## Printer relationship and capability adapter

Extend the existing PrintGateway boundary rather than calling platform APIs from multiple screens. The adapter should expose a normalized snapshot containing only information the active print service genuinely exposes: available media sizes, printable area/margins, orientation handling, color modes, duplex modes, resolution if available, and service/printer identity. Every capability must be tri-state or richer: supported, unsupported, or unknown/not exposed; include source and timestamp where meaningful.

The app must not claim to detect a physical printer when Android only exposes a generic print service. The OS print dialog remains authoritative for final driver-specific settings. If the service provides no capability API, keep the capability unknown and hand off a correctly sized PDF with an explicit note that the user must confirm media/settings in the system dialog.

A selected preset controls generated page geometry; it must not falsely imply that the physical device has selected that tray, stock, borderless mode or roll width.

## Recommendation and scaling rules

- Default to **fit/contain** when preserving all source content is more important than filling the page.
- Offer **fill/crop** only with a visible crop preview and undoable crop bounds.
- Offer **actual size / 100%** only when source physical dimensions are trustworthy; otherwise explain that the source has no reliable physical scale.
- Do not silently stretch non-matching aspect ratios.
- Compute printable area and margins when available; warn about clipping when unknown or incompatible.
- Calculate effective DPI from actual pixel dimensions and final physical output size. Warn about likely softness before large-format enlargement; never promise a quality threshold independent of content.
- Treat bleed, trim and crop marks as separate production geometry. Do not apply them to ordinary document scans without user intent.
- Large-format sizes can be used to design/export a PDF even if the current printer cannot physically print them. Distinguish **create/export size** from **available print size**.

## Local profiles and learning

Save user-approved preferences locally per printer/service identity and job class, such as office document, photo sheet, label, badge or poster. Profiles may remember the last-used size, orientation, fit policy, margins, color and duplex preference when exposed. They must be editable, clearable and visible before use. No cloud dependency is required. Usage history may improve recommendations deterministically, but must never silently change page geometry or trigger a print job.

## Validation and release gates

### Unit tests
- Registry IDs are unique; dimensions are finite and positive; standard dimensions match their declared values.
- Portrait/landscape transformations preserve geometry and do not duplicate fake standards.
- Source geometry and output media remain independent.
- Standard-size matching uses explicit tolerances and handles ambiguity.
- Fit/fill/actual-size math handles mismatched aspect ratios, rotations, margins and zero/invalid dimensions.
- Effective DPI and raster budgets are computed for small labels through large posters without unbounded allocations.
- Unknown printer capabilities remain unknown and do not become supported through defaults.
- Profile serialization/migration and corrupted preference recovery are safe.
- Custom media dimensions are validated and round-trip without unwanted rounding.

### Integration and device acceptance
- One media definition drives Scan Studio, photo sheets, design export, PDF output and print preview.
- Changing media size updates preview, scaling, DPI warnings and generated PDF page size together.
- Android system print handoff is tested with at least one real available print service; document the exact service/device and observed settings.
- Verify cancellation, returning from system dialog, unavailable printer, unsupported media and service failure.
- Compare generated PDFs in an independent reader and verify physical page dimensions.
- Run on a compact Android display and confirm settings remain readable and overrides are easy.
- Test offline; paper catalog and saved profiles must not require a network connection.

## Delivery sequence

1. Audit current paper catalog, design export, photo-sheet generation/dialog, Scan Studio metadata, PDF page setup and PrintGateway.
2. Extract/confirm the canonical registry API and add registry tests before changing screens.
3. Add normalized print-job geometry and scaling calculations, with unit tests.
4. Add the capability adapter and explicit unknown states; keep the system print dialog as fallback.
5. Connect all existing consumers to the shared job model in small reviewed changes.
6. Add local profile persistence and explainable auto-recommendations.
7. Validate generated PDFs, CI and real Android print-service behavior before marking complete.

## Non-goals and safety

Do not bundle printer-vendor drivers without a justified, licensed integration. Do not claim a printer's actual paper tray, stock, borderless ability or supported poster size unless the active service reports it. Do not silently crop, stretch, upscale, replace the source or dispatch a print job. Preserve originals and make transformations reviewable.
