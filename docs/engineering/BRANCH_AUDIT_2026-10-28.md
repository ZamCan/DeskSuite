# Repository branch audit — 2026-10-28

## Scope and method

This is a **branch-tip and feature-consolidation audit**, not a claim that every line in every historical commit has been manually proven correct. The audit compared fetched branch tips against the current `main` tree by path and blob hash, inspected changed feature modules and tests for the main open branches, reviewed the main CI history, and checked app identity, signing configuration, brand resources and current capability documentation.

For a complete local inventory, run `git fetch origin` followed by the lexical audit script from the isolated candidate branch if desired. That script counts source blobs, TODO markers and selected secret-pattern matches; it is not a substitute for semantic review, dependency/licence inspection or execution.

## Main integration decisions

| Branch / PR | What it contains | Decision |
| --- | --- | --- |
| `integration/full-product-consolidation-2026-10-28` / PR #8 | Reconciles PDF Studio, scan recovery, Creative Studio stamp/signature, print catalogue and current main. | **Merged** to main. |
| `integration/engine-completion-phase-1` / PR #9 | Bounded offline page-corner suggestion heuristic and tests; suggestions stay editable and require confirmation. | **Merged** to main after its four-platform CI matrix passed. |
| `engineering/pdf-studio-editor` / PR #6 | Existing-PDF editor and navigation. | Superseded by the PDF Studio now in main. Keep the branch as history; do not merge the old tree over main. |
| `integration/complete-product-android-ready` / PR #7 | Earlier all-in-one integration, PDF Studio and brand/scan updates. | Superseded by PR #8 plus PR #9. It has an older/failing combined CI snapshot; do not merge wholesale. |
| `engineering/scan-studio-ci-fixes` / PR #4 | Scan recovery changes and a prior version of the widget-test harness. | Main has the later consolidated scan flow/tests. Compare only future fixes that demonstrate a current failure; do not replace the test suite wholesale. |
| `engineering/engine-capability-audit` / PR #3 | Separate `ImageProcessingService` and separate Photo/PDF screens. | Do not merge the duplicate image engine or duplicate screens. Preserve the useful evaluation documents as reference. |
| `engineering/document-workflows-phase-1` / PR #2 | Earlier image tools, stamp/signature UI and an external-file opener. | Image/stamp capabilities are superseded in main. External-file handoff is deferred: the branch helper has no complete, validated native Android channel/provider integration and must not be presented as working. |
| `engineering/office-content-editor` / PR #5 | Office content editing/conversion. | Its content editing is already in main through the consolidated integration; the PR is closed. |
| `integration/pdf-studio` | PDF combine/inspection and custom Office layout-rendering experiments. | **Not merged wholesale.** This integration selectively ports PDF inspection/combination with 10-file / 48 MiB limits and output page-count checks. The Office renderer remains deferred: it is a partial parser/renderer, not a replacement for LibreOffice/Microsoft Office. CI, real-file and device validation are still required. |
| `agent/integration-candidate-20261028` and `agent/magic-scan-20261028` | Large 300+ file experiments: embedded Office WebAssembly/native WebView, templates, print/image optimizers, PDF inspection, artwork and fixtures. | Do not merge the full branch. This integration selectively ports Office ZIP preflight protection against malformed/oversized declarations and symlinks, plus focused tests. The embedded WebView/WASM engine, large binaries, alternate artwork and custom Office renderers remain deferred pending provenance/licences, isolation, fidelity and device review. |
| `agent/creative-studio-android`, `agent/document-workflows`, `integration/creative-studio-reconciled`, `integration/office-editor`, `release/0.2.0-integration` | Older product baselines or ancestors with overlapping workflows. | Preserve refs. No wholesale merge; use main as the single integration base. |

## Product architecture findings

- Main has one shared workspace and a single image processor; do not bring back the independent image engine from PR #3.
- Existing-PDF Studio is reachable through shared navigation/conversion. This integration adds ordered multi-PDF combination with bounded inputs and output validation; it is not full Acrobat parity.
- OCR is local but remains a distinct workflow; scan-to-PDF is image-based and not automatically searchable.
- Office editing is content-level. Full layout fidelity, formula/macros, rich text, and presentations remain limited.
- The starter stationery catalogue/sale log/receipt is not a full transactional POS.
- Photo and paper size presets are layout helpers, not official passport/ID acceptance guarantees.
- The canonical warm ink/paper/terracotta brand assets are kept. The experimental candidate's different section artwork and generated icon sources are not allowed to replace the approved mark without a separate review.
- Release signing remains owner-controlled. The repository's `android/key.properties` is ignored; the private keystore must not be committed or put into CI artifacts.

## Validation gate

The merged page-corner feature passed all four CI jobs on its exact feature head. The consolidated main CI run must still be checked on the **latest main commit**, since documentation edits after a run change its commit identity. Host CI is not proof of physical-device behavior.

Before release, verify on the phone: install/upgrade with the existing signing identity, camera/provider lifecycle, scan corner correction and output, OCR on real pages, opening/editing/saving PDFs, Office input/output round trips, print handoff, accessibility, low-memory recovery and Business record persistence. Inspect exported files in independent applications. Preserve user data and all branch refs during this process.
