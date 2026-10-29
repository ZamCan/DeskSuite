# DeskSuite branch integration ledger

Last reviewed: 2026-10-29
Default branch: `main`

## Non-negotiable integration rules

1. `main` is the only release/build source. Feature branches are staging areas, not alternate release homes.
2. Never merge a branch solely because its name says `complete`, `ready`, `integration`, or `phase-1`.
3. Before importing a branch, compare it with the current `main` base and inspect its commits, changed files, dependency/lockfile changes, tests, assets, permissions, and platform configuration.
4. Preserve valuable algorithms and designs by porting the smallest coherent units. Do not replace newer main files with older whole-file versions.
5. Require formatting, static analysis, tests, Android release build, and a documented manual/device check for camera, scanning, PDF, printing, and sales workflows where relevant.
6. Merge only a green pull request. Keep a record of the source branch and commit(s) from which each port was taken.
7. Delete a branch only after its unique useful work has been accounted for and the merged result is verified. A branch name alone is not proof that its work is redundant.
8. Do not commit keystores, passwords, signing properties, private customer data, build output, or generated duplicate APKs.

## Branch inventory (GitHub compare against current main)

Compared the following refs against `main` on 2026-10-29. “Ahead” means unique commits not present in main; “behind” is commits main has that the candidate lacks. A zero-ahead branch is historically behind main and contributes no unique commits in this comparison. Do not delete it until any externally valuable notes are checked.

| Branch | Ahead | Behind | Changed files in compare | Decision |
|---|---:|---:|---:|---|
| `agent/creative-studio-android` | 0 | 209 | 0 | No unique commits vs main; candidate for archival after final file/content spot-check |
| `agent/document-workflows` | 0 | 175 | 0 | No unique commits vs main; candidate for archival after final file/content spot-check |
| `agent/integration-candidate-20261028` | 23 | 29 | 242 | Diverged; do not merge wholesale; review unique assets and engine code in small batches |
| `agent/magic-scan-20261028` | 21 | 33 | 208 | Diverged; selectively review brand and scan assets; do not merge wholesale |
| `engineering/document-workflows-phase-1` | 48 | 189 | 28 | Diverged; review Android, document-format, and audit docs individually |
| `engineering/engine-capability-audit` | 27 | 189 | 11 | Diverged; review image engine and its tests as a coherent candidate |
| `engineering/office-content-editor` | 0 | 142 | 0 | No unique commits vs main; candidate for archival after final file/content spot-check |
| `engineering/pdf-studio-editor` | 20 | 169 | 13 | Diverged; review PDF editor, conversion catalog, and tests individually |
| `engineering/scan-studio-ci-fixes` | 8 | 169 | 2 | Diverged; scan Studio and widget test are a small reviewable unit |
| `integration/complete-product-android-ready` | 56 | 134 | 29 | Diverged; review release docs, brand assets, build workflow and unique modules; no wholesale merge |
| `integration/creative-studio-reconciled` | 0 | 191 | 0 | No unique commits vs main; candidate for archival after final file/content spot-check |
| `integration/engine-completion-phase-1` | 0 | 18 | 0 | No unique commits vs main; candidate for archival after final file/content spot-check |
| `integration/full-product-consolidation-2026-10-28` | 58 | 29 | 50 | Diverged and heavily changed; treat as a reference source only, port tested units |
| `integration/main-polish-engine-audit-20261028` | 53 | 6 | 33 | Nearer to main but diverged; high-priority review for engine register, current status, and startup polish |
| `integration/office-editor` | 0 | 140 | 0 | No unique commits vs main; candidate for archival after final file/content spot-check |
| `integration/pdf-studio` | 2 | 29 | 54 | Diverged; inspect the 54-file tree for meaningful unmerged work before deciding |
| `release/0.2.0-integration` | 0 | 132 | 0 | No unique commits vs main; candidate for archival after final file/content spot-check |
| `feature/premium-workspace-branding-20261028` | 20 | 0 | 16 | PR #11; current candidate branch; current matrix run `40811247150` is in progress; no merge until green |

## Product acceptance gates

- **Branding:** approved DeskSuite mark is used consistently for launcher, splash, workspace, and exported product identity.
- **Capture:** in-app preview and capture; safe rotation/lifecycle recovery; manual crop and perspective correction; multi-page ordering; enhancement; OCR where available; searchable/exportable output.
- **Creative/photo:** editability, reliable undo/redo, exact physical dimensions, aspect ratio, print resolution, crop preview, and export checks.
- **PDF/Office:** preserve original input; page/document structure; round-trip tests; clear unsupported-feature warnings; bounded memory for large files.
- **Print/POS:** explicit units and quantities; configurable currency; retail/wholesale tiers; deterministic totals and rounding; optional tax/discount settings; paper/ink/production cost; quotations, invoices, receipts, and stock reconciliation.
- **Release:** clean dependency lock; no secret leakage; `dart format`; `flutter analyze`; `flutter test`; Android APK/AAB builds; release artifact inspection; install/update test on a real device.

## Current blockers and known facts

- PR #11 had earlier failing/cancelled runs during test iteration. The latest observed matrix run is `40811247150` for head `b120ecbf50c64f85c4b5f234c3ac99ae01476e7b`, currently in progress at the time of this update. Treat earlier green-looking or cancelled runs as non-acceptance; inspect this exact head's final result before merge.
- The current `CameraGateway` uses `image_picker` and launches the device camera application. It is not the desired embedded CameraX-style capture experience.
- The current `pubspec.yaml` enforces the committed lockfile in CI. Dependency additions must include a correctly regenerated and reviewed `pubspec.lock`; do not add packages while leaving the lock stale.
- The full reference PNG should be compared with the user-approved logo, including safe-area and small-icon legibility. Passing the asset validator alone does not prove visual equivalence.

## Per-branch review record

For each candidate branch, record: source head SHA; base SHA; unique files and algorithms; dependency/lock changes; duplicate/conflicting implementations; tests added and executed; manual verification; PR URL; merged commit SHA; and whether the source branch can safely be archived. Until these fields are filled, mark it **not yet audited**, not “obsolete.”


## Selective duplicate check — 2026-10-29

A targeted content/hash check against `main` confirms that the current main branch already contains the exact same blobs as the premium workbench candidate and `integration/main-polish-engine-audit-20261028` for:

- `lib/office/office_zip_guard.dart` — bounded Office ZIP preflight and malformed-package rejection.
- `test/office_package_guard_test.dart` — malicious/corrupt ZIP guard regression tests.
- `lib/pdf/pdf_combine.dart` and `test/pdf_combine_test.dart` — bounded ordered PDF combination with output inspection.
- `pubspec.yaml` already declares the direct archive/XML dependencies used by Office package handling.

**Decision:** do not copy these files from old branches or create parallel implementations. They are already canonical on `main`; focus the branch audit on genuinely different UI, office rendering, scan, image, and print/POS work. The candidate's latest compare is 20 commits ahead, 0 behind, with 16 changed files; the PR head and changed-file count must be refreshed again before merge because CI/test fixes may add commits.

- `engineering/engine-capability-audit` `lib/image_engine/image_processing_service.dart` was reviewed against canonical `lib/images/photo_processor.dart`. Do **not** port it as a second image engine: it duplicates inspect/resize/crop/rotate behavior, permits a larger 40-megapixel synchronous decode path, and does not use the existing background-isolate boundary. Reuse or extend the canonical bounded processor instead; if an API is needed, add a thin adapter and tests around the existing limits.
- `integration/pdf-studio` contains a substantial separate Office renderer (`office_preview.dart`, `office_layout.dart`, `pptx_layout.dart`, `xlsx_layout.dart`) and brand/bootstrap work. These files are absent from main and are not safe to cherry-pick individually without their parser, layout, font, asset, and golden-test dependencies. Audit that branch as one coherent rendering feature and port only after format-specific fixtures and fidelity tests pass.
- `integration/complete-product-android-ready`'s `lib/documents/stamp_signature_tools.dart` is already present on main with matching file size but a different blob hash. Treat it as existing, not missing; compare the actual diff before considering any replacement.

- `engineering/scan-studio-ci-fixes` `lib/document_scan/scan_studio_page.dart` was compared line-by-line with `main`. The branch version is an older/smaller implementation (33,448 bytes vs 37,269 bytes) and lacks the current main branch's paper-catalog presets, custom physical dimensions (20–2500 mm validation), per-page orientation behavior, and export undo handling. Its useful note that image-only PDFs are not OCR-searchable should be retained in user-facing export guidance if not already present, but the branch file must **not** replace main.
