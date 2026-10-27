# Master directive — current implementation status

This is a status report for the current source, not a declaration that the overall directive or a release is complete. The full [master engineering directive](MASTER_ENGINEERING_DIRECTIVE.md), [additional owner instructions](OWNER_INSTRUCTIONS.md) and [previous progress response](PROGRESS_HISTORY.md) are preserved alongside it. The earlier [baseline audit](BASELINE_AUDIT.md) describes the starting state; [validation](VALIDATION.md) records actual host tests and remaining checks.

## Acceptance workflows

| Target | Current result | Missing or unverified |
| --- | --- | --- |
| A. Paper → searchable PDF | Manual corners, projective correction, tone/rotation, multipage ordering and **image-only** PDF exist. Added adjustable uneven-lighting and adaptive B&W cleanup with before/after preview. Draft reopen and earlier host-tested error/retry exist. | New cleanup UI/codecs and Android camera need full Flutter/device tests; OCR, searchable text, automatic detection and in-app PDF reopening are absent. Not complete. |
| B. Image → exact-size output | Photo Studio has fit or exact independent dimensions, PNG/JPEG encoding, output review and separate destination. Added 4-megapixel selective speck reduction, zoom, compare and a noisy garden exercise. | Native providers/device behavior and full Flutter suite, including the new cleanup UI/codec tests, are unverified. No percentage or physical-DPI resizing. |
| C. Existing document → extracted text | No arbitrary-document extraction or OCR service. Notes can export their own text only. | Real engine, editable extracted text, validation and export. Not complete. |
| D. Convert/compress | Explicit catalogue offers image → PNG/JPEG, image → image PDF, earlier design → new design and design → PNG/PDF. JPEG quality is adjustable and actual encoded size shown; source is not automatically overwritten. | Existing-PDF/Office conversion and PDF compression; size reduction is not guaranteed. Provider overwrite behavior must be tested. |
| E. New-user sample tutorial | Skippable/revisitable guides and fictional/synthetic examples invoke real scan/photo/design processors; outputs can be saved or reset. | Native/device testing; OCR and unsupported routes remain clearly unavailable. |

## Modules delivered in this source

- `lib/document_scan/`: camera boundary, manual corners, projective processor, local lighting/adaptive B&W pixel cleanup, preview dialog, image-PDF assembly and private draft. New Flutter integration tests are written but not yet run.
- `lib/images/photo_processor.dart`, `image_cleanup_pixels.dart` and Photo Studio in `lib/legacy_studios.dart`: bounded image operations, selective isolated-speck filter, comparison and encoded-output review.
- `lib/workspace/getting_started_page.dart`, `conversion_catalog.dart` and `conversion_catalog_page.dart`: real-tool guides and capability catalogue.
- `assets/samples/`, `assets/brand/` and Android resources: fictional examples including deliberately shadowed field notes and a noisy synthetic garden, editable example and D+S branding. See [before/after pixel-engine evidence](cleanup-evidence.png) and [brand instructions](BRAND_ASSETS.md).
- `test/`: targeted engine, recovery, sample and compact/landscape widget tests. The standalone cleanup pixel smoke check ran via DartPad DDC/Node; the new Flutter tests and complete final suite remain pending.

## Release and next stage

The Android application ID remains `com.zamcan.desksuite`; no release signing credentials are supplied. No current APK or AAB has been built, signature-verified, installed or run. A remote branch named `engineering/document-workflows-phase-1` was discovered separately and diverges from this source; it was not overwritten or merged. Reconcile independently and test before any integration.

Next: run the new cleanup tests and full host suite and Android build using the owner's existing toolchain; validate cleanup on real photographs, low-memory devices and the compact/landscape UI, plus native capture/storage/splash and upgrade behavior. Then implement one pinned offline OCR → editable TXT slice with a disclosed language model and real recognition tests. Searchable PDF and a PDF reader require additional separate work. See [engine evaluation](ENGINE_EVALUATION.md), [development](../DEVELOPMENT.md) and [roadmap](../ROADMAP.md).
