# DeskSuite — current engineering status

**Status date:** 2026-10-28  
**Product:** DeskSuite — Android-first creative, office, document, print-production and stationery-business workspace  
**Current source:** main at the consolidated PDF/scan baseline plus the offline page-corner suggestion engine. See the [current main commit](https://github.com/ZamCan/DeskSuite/commits/main).

This is an implementation report, not a claim of production readiness. The full requirements remain in [MASTER_ENGINEERING_DIRECTIVE.md](MASTER_ENGINEERING_DIRECTIVE.md); initial findings are in [BASELINE_AUDIT.md](BASELINE_AUDIT.md); the selective branch review is in [BRANCH_AUDIT_2026-10-28.md](BRANCH_AUDIT_2026-10-28.md).

## Validation state

- The previous main snapshot `7f1920ef` passed `flutter analyze`, the full Flutter test suite, Android APK/AAB compilation, Windows/Linux builds and unsigned iOS validation in [CI run 40689024580](https://github.com/ZamCan/DeskSuite/actions/runs/40689024580).
- The offline page-corner suggestion feature passed the four-platform matrix on its exact feature branch in [CI run 40690205064](https://github.com/ZamCan/DeskSuite/actions/runs/40690205064).
- The merged main tree contains both sets of work. Follow the [main-branch CI runs](https://github.com/ZamCan/DeskSuite/actions/workflows/build.yml?query=branch%3Amain) and verify the run whose head SHA matches the current `main` before treating the source as validated. Documentation and audit updates followed the earlier build run, so its result is not a substitute for the latest-head run.
- No physical-device installation, camera lifecycle, real printer, independent-reader PDF fidelity or signed upgrade has been verified here.

## Implemented source capabilities

| Area | Present in source | Boundary that must remain explicit |
| --- | --- | --- |
| Scan & assemble | Local image import, Android camera-capture entry point, manual perspective correction, optional bounded page-corner suggestions, rotation/tone cleanup, multipage ordering, draft recovery and image-based PDF/PNG export. | Corner suggestions are heuristic and require review/correction. Automatic universal edge detection, device camera/provider lifecycle and process-death recovery need device validation. Scan PDF output is image-based. |
| OCR | Local Tesseract bridge and English / English+Kiswahili models, image preparation, editable text review, TXT/DOCX export and searchable-PDF text layer. | OCR accuracy is not guaranteed; the OCR screen is separate from scan PDF export. Test real pages and the target phone. |
| Photo Studio / images | Bounded decode, rotate/crop/resize, physical-size-to-pixel conversion, JPEG quality/size optimisation, selective speck reduction, background placement for existing transparency, output review and separate-copy export. | No automatic background removal, biometric crop, universal passport compliance or calibrated DPI/print guarantee. |
| Creative Studio | Shared editable design document, text/shapes/images, starter layouts, photo-sheet layout and image-slot placement, stamps/signatures, history, save/reopen and PNG/PDF export. | Starter templates are examples, not authority-approved designs. Complex multi-page/presentation authoring and PPTX export are not complete. |
| PDF Studio | Existing-PDF import, bounded edit/review and save-as-copy flow. The integration candidate adds ordered combination of up to 10 PDFs / 48 MiB aggregate input with output page-count validation. | The new combine path still needs CI, independent-reader and physical-device validation. Split, structural compression and encrypted output remain unimplemented; complex/protected PDFs may fail. |
| Office | Bounded package reading and content-level editing/conversion for supported DOCX/XLSX/PPTX/ODF/RTF/text/HTML routes. | Not a full Word/Excel/PowerPoint layout editor. Formula, macro, image, font and complex-layout fidelity is limited; full layout rendering needs a separately evaluated engine. |
| Printing | Paper/physical-size catalogues, photo sheets, print-check PDF and OS print handoff boundary. | Printer discovery, margins/scaling, colour, stock compatibility and actual device output need testing. |
| Stationery Business | Local starter catalogue/stock and recorded sale log with reprintable A5 PDF receipt. | Not a complete transactional POS: baskets, supplier purchasing, refunds, expenses, customer balances, audit ledger and reliable profit reports remain missing. |
| App shell and brand | One shared workspace, warm paper/ink/terracotta identity, bundled SVG/raster mark, Android adaptive/monochrome/legacy icons and splash resources. | Test launcher appearance, accessibility, small screens and OS-specific behavior on physical devices. |

## Build and signing

- Android application ID: `com.zamcan.desksuite`.
- Keep the existing private keystore and `android/key.properties` on the owner's machine only. They are ignored by Git.
- CI can compile APK/AAB artifacts, but it does not possess the owner's private signing key; **do not treat a CI artifact as a signed update**.
- To preserve an installed app's data, build locally with the same signing identity. Use `bash tools/build-android.sh release` after confirming the existing key configuration. The script refuses release mode if `android/key.properties` is missing.
- Never paste the keystore password into chat or commit the keystore/properties file. Verify the resulting APK certificate before installing.

See [DEVELOPMENT.md](../DEVELOPMENT.md) for the local build workflow and [VALIDATION.md](VALIDATION.md) for the recorded host results.

## Next actions, in order

1. Confirm the latest main CI run passes on its exact head.
2. Pull `main` in Termux without discarding local work, verify the existing signing-key configuration without printing secrets, and build a signed APK with the owner's existing key.
3. Install as an update, then inspect Home/navigation, Scan & assemble, OCR, Photo Studio, PDF Studio, Office, Creative Studio, Print and Business on the phone. Record crashes, overflows, permission/provider errors and output-file failures.
4. Fix device-found issues before adding large new engines.
5. Validate the selected PDF inspection/combination and Office ZIP preflight changes in this branch. Evaluate richer print-image optimisation and Office preview separately with dependency/licence, memory, security and real-file tests. Do not merge the experimental Office WebAssembly branch wholesale.
6. Complete POS transactions, backup/restore, PDF page operations, native file-provider integration, printer/device testing and Office interoperability before claiming a release-ready product.

