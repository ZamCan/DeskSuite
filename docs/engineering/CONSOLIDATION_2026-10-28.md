# Single-main consolidation record — 2026-10-28

## Scope and safety

The owner requested a careful audit of every remote branch, consolidation of useful underlying work without parallel duplicate engines, and eventually a single remote `main`. The public repository had **18 heads**, with `main` at `177a10f80f51c31ba6de7cc7bb2e321f6e9e07c4`. A complete preconsolidation bundle and exact ref manifest were independently restored and checked with `git fsck`; bundle SHA-256:

`09c0fb1d6c0feae045d003b4f64f6ec0cf3706d037f3945f18f543ae7c058a1e`

A merge-base/commit/path inventory and targeted semantic comparisons were performed. This is not an exhaustive security or per-line correctness audit. Main had advanced beyond the earlier candidate, so the candidate was **not** merged wholesale. Instead, selected functionality was applied to the newer main while retaining PDF combine, scan recovery, Office page sizing, stamps/signatures and signing safeguards. No branch deletion is justified until the exact consolidation passes the owner's tests, remote heads are rechecked and a recoverable bundle is retained independently of the Git hosting service.

## Review of all heads

| Remote head | Finding and disposition in this source |
| --- | --- |
| `main` | Baseline `177a10f`; retain as the eventual single authoritative branch. Its exact-head CI run passed before these later changes. |
| `agent/creative-studio-android` | Ancestor of baseline; no branch-tip change to port. |
| `agent/document-workflows` | Ancestor of baseline; cleanup/sample ideas also reconciled from the later candidate. |
| `agent/integration-candidate-20261028` | Diverged candidate with ID/photo slots, OOXML starter files, examples, blue branding, scan/OCR, image/print safeguards and experimental Office preview. Useful pieces were selectively integrated, not the older whole tree. |
| `agent/magic-scan-20261028` | Earlier feature line and ancestor of the candidate; selected artwork, cleanup, image and preview work covered through the candidate. |
| `engineering/document-workflows-phase-1` | Earlier image tools/stamps duplicate newer canonical paths. It also contains a native channel and FileProvider for opening a temporary read-only copy in another app; it is not the same as editing the source, writes a cache copy and has not been integrated or device-verified. Do not claim the native pieces are absent or the handoff is production-ready. |
| `engineering/engine-capability-audit` | Separate image engine and Photo/PDF screens overlap the existing shared processor/workspace. Kept one canonical implementation rather than introducing competing engines. |
| `engineering/office-content-editor` | Ancestor of baseline; current content editor retained. |
| `engineering/pdf-studio-editor` | Earlier PDF integration superseded by the main editor and combine, supplemented by the candidate's bounded inspection and split/export safeguards. |
| `engineering/scan-studio-ci-fixes` | Earlier scan recovery/test work superseded by the later baseline; its recovery-before-clear intent remains in main. |
| `integration/complete-product-android-ready` | Earlier all-in-one and signing workflow superseded by main's guarded local signing script and newer source. Do not replace main's signing controls. |
| `integration/creative-studio-reconciled` | Ancestor of baseline; no branch-tip change to port. |
| `integration/engine-completion-phase-1` | Ancestor of baseline; bounded page-corner suggestions retained. |
| `integration/full-product-consolidation-2026-10-28` | Scan undo/recovery, stamps, PDF, shared print media and Office page sizing are already represented in the newer baseline. Wholesale merge would discard later safety work. |
| `integration/main-polish-engine-audit-20261028` | Newer main contains its PDF combine, bounded ZIP preflight/CRC, version/signing and navigation work. Warm-brand conclusion is superseded by the owner's subsequent blue-icon selection. |
| `integration/office-editor` | Ancestor of baseline; Office content workflow retained. |
| `integration/pdf-studio` | Contains a separate custom partial PPTX/XLSX layout renderer and older warm boot/palette experiment. The partial renderer expands worksheet row indexes and merged ranges without adequate bounds and decodes embedded pictures without demonstrated device limits; it also duplicates significant parsing logic. It was **not** enabled or copied wholesale. The separate opt-in OpenDocument.core preview supplies a genuine read-only rendering-engine experiment on Android but does not replace this unverified desktop experiment or provide editing/conversion. The unique branch remains recoverable in the complete bundle. |
| `release/0.2.0-integration` | Ancestor of baseline; no branch-tip change to port. |

## Key consolidation choices

- One shared photo processor, scan image-PDF writer, physical media catalogue, PDF inspection/filename helper and bounded Office package reader are retained. Office detection and content extraction reuse one validated inflated package for each read.
- ID cards are fictional editable layouts; marked photo slots use the existing design model. Six actual OOXML starters save their original bytes. Scan and photo samples are fictional and use ordinary workflows.
- The selected blue icon is shared by the app, Android, Windows and AppImage; other candidates are section artwork. Animated launch honours reduced motion. Device launcher/splash behavior remains unverified.
- Scan cleanup modes are local pixel heuristics, not guaranteed restoration. Scan-to-OCR uses the selected processed page and the existing recognizer, without making scan PDFs automatically searchable.
- PDF open/output inspection uses the same 48 MiB app budget as the picker and main editor. Split is limited to 100 files/48 MiB aggregate output and reports partial saves; combine UI and existing tests remain. A save picker can overwrite a source selected as destination.
- The OpenDocument.core preview is opt-in, disabled by default and read-only. Its WebView isolation, Android lifecycle, fidelity, memory and binary-licence closure require verification. The built-in content editor remains a separate lossy path, not a layout-faithful Office round trip.

## Remaining gates before promotion or deletion

1. On the owner's existing Flutter/Dart toolchain run formatting, full analysis and full tests on this exact tree, then fix failures. Host scripts, DartPad/Node and fake-interface checks are useful but do not replace these gates.
2. Validate real PDF editor callbacks, independent PDF files, OCR, picker/camera, Office compatibility/WebView isolation, accessibility, low-memory behavior and printer output on physical devices. Review dependency notices and the exact native/WASM binary closure before distribution.
3. Re-fetch/list all remote heads and open PRs; verify no new work is lost. Preserve the bundle and ref manifest in an independent location and verify restore before retiring heads.
4. The existing main push/PR workflow builds and packages APK/AAB and desktops online; the owner requests local packaging and no toolchain downloads. Resolve the publishing/CI policy deliberately. A CI skip would bypass full verification and may interact with protected-branch requirements; it is not a test pass. Do not modify the workflow, trigger builds, push unvalidated changes or delete branches without resolving the gates and obtaining authenticated access.
5. Keep app ID `com.zamcan.desksuite` and the existing private signing identity. No APK/AAB has been built, signed, installed or device-tested for this consolidation.
