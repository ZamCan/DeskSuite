# Repository branch audit — 2026-10-28

> **Superseded status, 2026-10-28:** This is the historical main-polish audit, not the current consolidation decision. The owner subsequently selected the blue dimensional DS icon; the selected artwork, starter templates and opt-in Android OpenDocument.core WASM preview are now selectively present in the consolidation source. The older warm-brand and “preview deferred” conclusions below are historical. The earlier external-file branch does contain a native channel/provider, but its cached read-only handoff remains unintegrated and unverified. See [current all-head consolidation](CONSOLIDATION_2026-10-28.md) and [current status](CURRENT_STATUS.md). No remote branch deletion is implied by the historical recommendations below.


## Scope and method

This is a **branch-tip and feature-consolidation audit**, not a claim that every line in every historical commit has been manually proven correct. The audit compared fetched branch tips against the current `main` tree by path and blob hash, inspected changed feature modules and tests for the main open branches, reviewed the main CI history, and checked app identity, signing configuration, brand resources and current capability documentation.

For a complete local inventory, run `git fetch origin` followed by the lexical audit script from the isolated candidate branch if desired. That script counts source blobs, TODO markers and selected secret-pattern matches; it is not a substitute for semantic review, dependency/licence inspection or execution.

## Main integration decisions

| Branch / PR | What it contains | Decision |
| --- | --- | --- |
| `integration/full-product-consolidation-2026-10-28` / PR #8 | Reconciles PDF Studio, scan recovery, Creative Studio stamp/signature, print catalogue and current main. | **Merged** to main. |
| `integration/engine-completion-phase-1` / PR #9 | Bounded offline page-corner suggestion heuristic and tests; suggestions stay editable and require confirmation. | **Merged** to main after its four-platform CI matrix passed. |
| `engineering/pdf-studio-editor` / PR #6 | Existing-PDF editor and navigation. | Superseded by the PDF Studio now in main. No branch-only paths remain; retire the remote branch after the final inventory. |
| `integration/complete-product-android-ready` / PR #7 | Earlier all-in-one integration, PDF Studio and brand/scan updates. | Superseded by PR #8 plus PR #9. It has an older/failing combined CI snapshot; do not merge wholesale. |
| `engineering/scan-studio-ci-fixes` / PR #4 | Scan recovery changes and a prior version of the widget-test harness. | Main has the later consolidated scan flow/tests. Compare only future fixes that demonstrate a current failure; do not replace the test suite wholesale. |
| `engineering/engine-capability-audit` / PR #3 | Separate `ImageProcessingService` and separate Photo/PDF screens. | Do not merge the duplicate image engine or duplicate screens. Preserve the useful evaluation documents as reference. |
| `engineering/document-workflows-phase-1` / PR #2 | Earlier image tools, stamp/signature UI and an external-file opener. | Image/stamp capabilities are superseded in main. External-file handoff is deferred: the branch helper has no complete, validated native Android channel/provider integration and must not be presented as working. |
| `engineering/office-content-editor` / PR #5 | Office content editing/conversion. | Its content editing is already in main through the consolidated integration; the PR is closed. |
| `integration/pdf-studio` | PDF combine/inspection and custom Office layout-rendering experiments. | **Not merged wholesale.** This integration selectively ports PDF inspection/combination with 10-file / 48 MiB limits and output page-count checks. The Office renderer remains deferred: it is a partial parser/renderer, not a replacement for LibreOffice/Microsoft Office. CI, real-file and device validation are still required. |
| `agent/integration-candidate-20261028` and `agent/magic-scan-20261028` | Large 300+ file experiments: embedded Office WebAssembly/native WebView, templates, print/image optimizers, PDF inspection, artwork and fixtures. | Do not merge the full branch. This integration selectively ports Office ZIP preflight protection against malformed/oversized declarations and symlinks, plus focused tests. The embedded WebView/WASM engine, large binaries, alternate artwork and custom Office renderers remain deferred pending provenance/licences, isolation, fidelity and device review. |
| `agent/creative-studio-android`, `agent/document-workflows`, `integration/creative-studio-reconciled`, `integration/office-editor`, `release/0.2.0-integration` | Older product baselines or ancestors with overlapping workflows. | No wholesale merge; these tips are stale or contain no unique current files. Retire their remote refs after the final inventory. |

## Product architecture findings

- Main has one shared workspace and a single image processor; do not bring back the independent image engine from PR #3.
- Existing-PDF Studio is reachable through shared navigation/conversion. This integration adds ordered multi-PDF combination with bounded inputs and output validation; it is not full Acrobat parity.
- OCR is local but remains a distinct workflow; scan-to-PDF is image-based and not automatically searchable.
- Office editing is content-level. Full layout fidelity, formula/macros, rich text, and presentations remain limited.
- The starter stationery catalogue/sale log/receipt is not a full transactional POS.
- Photo and paper size presets are layout helpers, not official passport/ID acceptance guarantees.
- **Logo/UI audit:** current `main` already contains the approved D+S SVG and transparent PNG, the native Flutter `BrandMark`, Android legacy/adaptive/monochrome launcher resources, and the warm shared theme. The logo is not missing. However, the experimental candidate's six raster section illustrations and blue theme are not merged; its palette conflicts with the approved warm identity. This branch keeps the existing logo and ports a warm, compact selected/unselected navigation icon treatment plus a branded startup/loading view, without introducing a fixed launch delay or new image dependency.
- The older `integration/pdf-studio` branch has a custom PPTX/XLSX layout renderer and a drawn boot sequence. The renderer is not copied wholesale because it is a partial OOXML implementation, has significant surface area and must be reviewed against current Office ZIP guards and real-file fidelity. The branded boot sequence is not copied verbatim because its theme API conflicts with main; the same UX goal is met with the canonical existing `BrandMark` and current theme.
- Release signing remains owner-controlled. The repository's `android/key.properties` is ignored; the private keystore must not be committed or put into CI artifacts.

## Validation gate

The merged page-corner feature passed all four CI jobs on its exact feature head. The consolidated main CI run must still be checked on the **latest main commit**, since documentation edits after a run change its commit identity. Host CI is not proof of physical-device behavior.

Before release, verify on the phone: install/upgrade with the existing signing identity, camera/provider lifecycle, scan corner correction and output, OCR on real pages, opening/editing/saving PDFs, Office input/output round trips, print handoff, accessibility, low-memory recovery and Business record persistence. Inspect exported files in independent applications. Preserve user data and main history. The owner's later directive is to retire redundant remote refs after consolidation, leaving `main` as the sole branch.


## Final branch-tip inventory after PR #10

The repository had 18 branch refs including `main` at the audit timestamp. The live tree comparison against `main` shows:

| Remote branch | Tip relationship to main | Unique material / decision |
| --- | --- | --- |
| `main` | authoritative | Keep. Latest integrated build matrix passed for Android APK/AAB, Linux, Windows and unsigned iOS validation. |
| `agent/creative-studio-android` | 0 ahead / 204 behind; no unique paths | Stale baseline; safe to retire. |
| `agent/document-workflows` | 0 ahead / 170 behind; no unique paths | Stale baseline; safe to retire. |
| `agent/integration-candidate-20261028` | diverged, 23 ahead / 24 behind | Unique Office WASM/WebView payload (~5.9 MiB WASM), alternate artwork, sample templates, experimental preview and image/print helpers. Do not merge wholesale; renderer/licence/device gates remain open. |
| `agent/magic-scan-20261028` | diverged, 21 ahead / 28 behind | Overlaps the integration candidate and includes alternate scan/artwork changes. No blind merge; review only a demonstrable missing feature. |
| `engineering/document-workflows-phase-1` | diverged, 48 ahead / 184 behind | Unique older image-tools screen/service and external-file helper. Image service duplicates canonical image processing; external-file helper lacks validated native handoff. Defer these, not core requirements. |
| `engineering/engine-capability-audit` | diverged, 27 ahead / 184 behind | Separate image engine and standalone Photo/PDF screens duplicate the canonical engine/workspace. Defer wholesale. |
| `engineering/office-content-editor` | 0 ahead / 137 behind; no unique paths | Superseded by merged Office work; safe to retire. |
| `engineering/pdf-studio-editor` | diverged, 20 ahead / 164 behind; no unique paths | Superseded PDF Studio/test revision; safe to retire. |
| `engineering/scan-studio-ci-fixes` | diverged, 8 ahead / 164 behind; no unique paths | Older scanner/test fixes; main has the later consolidated implementation. Safe to retire. |
| `integration/complete-product-android-ready` | diverged, 56 ahead / 129 behind | Superseded PR #7 closed on 2026-10-28. Its phone build script duplicates the canonical `tools/build-android.sh`; the signing-verification/install guard was consolidated into that one script. Unique old docs/icon generator are not runtime requirements. |
| `integration/creative-studio-reconciled` | 0 ahead / 186 behind; no unique paths | Already superseded by merged integration; safe to retire. |
| `integration/engine-completion-phase-1` | 0 ahead / 13 behind; no unique paths | PR #9 feature is in main; safe to retire. |
| `integration/full-product-consolidation-2026-10-28` | diverged, 58 ahead / 24 behind; no unique current paths | PR #8 is merged. Its useful product changes are represented in main; do not remerge the divergent tip. Safe to retire. |
| `integration/main-polish-engine-audit-20261028` | diverged, 53 ahead / 1 behind | PR #10 is merged; all files in its candidate tree are represented in main. Safe to retire. |
| `integration/office-editor` | 0 ahead / 135 behind; no unique paths | Superseded Office branch; safe to retire. |
| `integration/pdf-studio` | diverged, 2 ahead / 24 behind | Unique custom PPTX/XLSX partial layout renderer and boot/branding experiments. Defer: significant parser surface area, partial fidelity, and no proof of full compatibility with current ZIP safety. |
| `release/0.2.0-integration` | 0 ahead / 127 behind; no unique paths | Stale release baseline; safe to retire. |

### Consolidation decisions

- Do not bring in alternative image-processing services or duplicate studio screens merely because they are branch-only.
- Do not add a large Office WASM binary or custom PPTX/XLSX renderer until source/licence provenance, isolation, real-file fidelity, memory bounds, and Android-device tests are demonstrated.
- The owner-requested signing safeguard is now in the single canonical Android build script: release builds require local signing configuration, APK signatures are checked, and optional ADB installation refuses to overwrite an installed app when its certificate differs. `android/key.properties.example` contains placeholders only.
- No source file is removed from `main` merely because another branch has a similarly named implementation. Main's current tests and successful build matrix remain the deletion gate.

### Remote-ref cleanup status

The inventory above identifies 17 non-main refs as stale/superseded or intentionally deferred. The connected GitHub actions available in this session support reading branch refs and updating files/PR state, but do not expose a branch-delete operation. PR #7 is closed; **the remote branch refs have not been deleted by this session**. Do not report the repository as having only one branch until a GitHub owner-side branch deletion or authenticated `git push origin --delete …` operation confirms that only `main` remains.
