# DeskSuite engineering roadmap

This roadmap is the short, current action list. The full scope and product requirements remain in [MASTER_ENGINEERING_DIRECTIVE.md](engineering/MASTER_ENGINEERING_DIRECTIVE.md); the exact present implementation is in [CURRENT_STATUS.md](engineering/CURRENT_STATUS.md). “Implemented” means code exists, not that it is production-certified.

## Stage 0 — consolidate and install

- [x] Keep a single shared Flutter workspace and product identity on `main`.
- [x] Integrate Scan & assemble, OCR, Photo Studio, Creative Studio, Office content workflows, existing-PDF Studio, print tools and starter inventory/POS without duplicating the image engine.
- [x] Integrate bounded, offline page-corner suggestions with manual correction and explicit confirmation.
- [x] Preserve the existing package ID and keep private signing material out of the repository.
- [ ] Confirm CI passes on the exact latest `main` commit.
- [ ] Pull to Termux, build with the existing private signing key, verify the certificate and install as an update on the same phone.
- [ ] Complete a real-device smoke pass and record results before the next large feature integration.

## Stage 1 — scanner and PDF reliability

- [x] Local image import, manual perspective correction, page ordering, draft storage and image-PDF export.
- [x] Offline corner suggestions that remain editable and never auto-apply without user confirmation.
- [ ] Validate camera capture, permission/provider behavior, app backgrounding, process death and low-memory recovery on the phone.
- [ ] Add robust automatic page detection only after evaluating real-document false positives and manual fallback.
- [x] Integrate bounded PDF combine/inspection and page/split callbacks in source.
- [ ] Validate those callbacks, independent files and device memory on the exact consolidated tree.
- [ ] Validate encrypted, malformed, large and complex PDFs; independently open every exported result.
- [ ] Add PDF text search/extraction, accessible preview and structural compression only with a tested compatible engine.
- [ ] Add encrypted output only after key handling and format interoperability are reviewed.

## Stage 2 — image and print-production engine

- [x] Shared bounded image decode/transform engine, pixel and physical-size resize, JPEG quality control and image-based PDF output.
- [x] Photo-sheet layouts and editable image slots in Creative Studio.
- [ ] Evaluate image-compression/raster-budget helpers from unmerged branches against current `lib/images/` code before adoption; retain one implementation per task.
- [ ] Add arbitrary crop/selection, layers/masks, richer colour adjustments and non-destructive edits.
- [ ] Evaluate optional local background segmentation with licence, memory, latency and offline checks; do not silently download models.
- [ ] Add calibrated print presets, bleed/crop marks, imposition and real printer tests.
- [ ] Add authority-specific ID/photo templates only where physical requirements are verified. Generic size presets must not be described as official passport standards.
- [ ] Support posters, badges, labels and all relevant paper/media dimensions with bounded high-resolution rendering.

## Stage 3 — Office engine and document interoperability

- [x] Bounded package readers and content-level editing/conversion for the explicitly supported document routes.
- [ ] Improve editability and round-trip preservation for DOCX/XLSX/PPTX/ODF, including images, styles, formulas, page breaks and tables.
- [x] Retain an opt-in, disabled-by-default Android Office WASM preview in source.
- [ ] Independently verify its sandbox, binary provenance/licences, accessibility, fidelity and device memory before enabling or distributing.
- [ ] Compare any Office rendering engine against real reference documents and independent desktop office suites; document fidelity limits by route.
- [ ] Add true rich-text editing, spreadsheet formulas, presentation editing and export formats only through a maintained, tested engine.
- [ ] Keep conversion routes explicit when a format or operation is unsupported; never imply that a file was converted when only its text was extracted.

## Stage 4 — complete stationery POS and records

- [x] Starter stationery catalogue, local stock counters, recorded sale log and reprintable A5 receipt.
- [ ] Transactional multi-item basket with stock ledger, stable sale IDs, exact currency arithmetic and rollback/recovery.
- [ ] Supplier and purchase records, refunds/voids, customer balances, expenses, profit reporting and audit trail.
- [ ] Quote/invoice layouts, tax configuration and export/print flows; verify local legal requirements before claiming compliance.
- [ ] Backup/restore, schema migrations, storage-full and crash tests, with explicit user control over private business data.

## Stage 5 — cross-platform, accessibility and release

- [x] Shared Flutter product architecture and CI build matrix for Android, Windows, Linux and unsigned iOS validation.
- [ ] Test native plugins, file paths, fonts, storage, printing and accessibility independently on each OS.
- [ ] Audit all direct/transitive dependencies, embedded binaries, licences, network boundaries and Android permissions.
- [ ] Complete screen-reader semantics, keyboard navigation, narrow-screen layouts, dark theme consistency and low-memory profiling.
- [ ] Produce a reproducible signed Android release with stable package identity and owner-held key custody.
- [ ] Pass cold-start, offline, update-install, process-death, backup/restore and real-output acceptance tests before release.

## Explicitly not a claim today

DeskSuite is **not yet** a full Microsoft Office/LibreOffice replacement, Acrobat/CamScanner equivalent, biometric passport-photo certification tool or complete retail accounting system. No cloud account, paid API or remote model download is required for the core local flows. Any future optional engine must preserve that offline-first contract and be evaluated before integration.
