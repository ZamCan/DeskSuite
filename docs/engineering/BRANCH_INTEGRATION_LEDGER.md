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

## Branch inventory (initial triage)

The following branches were visible during this review. This is an inventory, not a claim that every branch has already been line-by-line audited.

| Branch | Initial role inferred from name | Integration status |
|---|---|---|
| `main` | Canonical product | Protected as release source; current baseline |
| `feature/premium-workspace-branding-20261028` | Task-first workspace and supplied brand mark | Candidate PR #11; CI failed at `flutter analyze`; not merge-ready |
| `agent/creative-studio-android` | Creative studio work | Needs diff and behavior review |
| `agent/document-workflows` | Document workflow work | Needs diff and behavior review |
| `agent/integration-candidate-20261028` | Integration candidate | Needs diff and behavior review |
| `agent/magic-scan-20261028` | Scan and brand assets | Candidate assets found; needs diff, dependency, and device review |
| `engineering/document-workflows-phase-1` | Document workflows phase 1 | Needs diff and tests review |
| `engineering/engine-capability-audit` | Engine capability audit | Candidate audit material; reconcile with current code |
| `engineering/office-content-editor` | Office content editor | Needs diff and format-preservation tests |
| `engineering/pdf-studio-editor` | PDF editing studio | Needs diff, memory/performance, and PDF fidelity tests |
| `engineering/scan-studio-ci-fixes` | Scan Studio/CI work | Existing camera gateway delegates to external camera app; not native in-app capture |
| `integration/complete-product-android-ready` | Broad Android integration | Needs full diff and clean CI; branch label is not validation |
| `integration/creative-studio-reconciled` | Reconciled creative studio | Needs diff and conflict review |
| `integration/engine-completion-phase-1` | Engine completion phase 1 | Needs diff and behavior tests |
| `integration/full-product-consolidation-2026-10-28` | Broad consolidation | Previously observed far ahead and behind main; do not wholesale merge |
| `integration/main-polish-engine-audit-20261028` | Main polish and audit | Needs diff and test review |
| `integration/office-editor` | Office editor | Needs diff and document round-trip tests |
| `integration/pdf-studio` | PDF studio | Needs diff and rendering/edit/export tests |
| `release/0.2.0-integration` | Historical release candidate | Check for unique fixes; do not replace current version metadata blindly |

## Product acceptance gates

- **Branding:** approved DeskSuite mark is used consistently for launcher, splash, workspace, and exported product identity.
- **Capture:** in-app preview and capture; safe rotation/lifecycle recovery; manual crop and perspective correction; multi-page ordering; enhancement; OCR where available; searchable/exportable output.
- **Creative/photo:** editability, reliable undo/redo, exact physical dimensions, aspect ratio, print resolution, crop preview, and export checks.
- **PDF/Office:** preserve original input; page/document structure; round-trip tests; clear unsupported-feature warnings; bounded memory for large files.
- **Print/POS:** explicit units and quantities; configurable currency; retail/wholesale tiers; deterministic totals and rounding; optional tax/discount settings; paper/ink/production cost; quotations, invoices, receipts, and stock reconciliation.
- **Release:** clean dependency lock; no secret leakage; `dart format`; `flutter analyze`; `flutter test`; Android APK/AAB builds; release artifact inspection; install/update test on a real device.

## Current blockers and known facts

- PR #11 changes the home workbench and brand assets, but its GitHub Actions run failed during `flutter analyze`; its test and Android build steps were skipped. Do not merge it until the diagnostics are obtained, corrected, and the latest commit passes.
- The current `CameraGateway` uses `image_picker` and launches the device camera application. It is not the desired embedded CameraX-style capture experience.
- The current `pubspec.yaml` enforces the committed lockfile in CI. Dependency additions must include a correctly regenerated and reviewed `pubspec.lock`; do not add packages while leaving the lock stale.
- The full reference PNG should be compared with the user-approved logo, including safe-area and small-icon legibility. Passing the asset validator alone does not prove visual equivalence.

## Per-branch review record

For each candidate branch, record: source head SHA; base SHA; unique files and algorithms; dependency/lock changes; duplicate/conflicting implementations; tests added and executed; manual verification; PR URL; merged commit SHA; and whether the source branch can safely be archived. Until these fields are filled, mark it **not yet audited**, not “obsolete.”
