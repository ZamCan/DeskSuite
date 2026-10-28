# Branch integration audit — 2026-10-28

**Status: isolated integration candidate, not a production main or release.**
The starting feature is `90904cd80c80` and fetched `main` is `cb1e264bb951`.
The worktree combines those trees while preserving separate remote branches.
The owner requested no remote packaging; no pull request, main push, workflow
run or new Android toolchain was initiated for this candidate.

## Snapshot and coverage

After a fresh public `git fetch origin`, `python3 tools/audit_repository_branches.py`
inventoried **15 origin branch tips**, 428 distinct blobs in selected first-party
code paths, and about 109,032 newline-terminated lines across those different
branch versions. Its roughly 4,943 Dart callable-like matches are a *lexical
estimate*, not a count of actual functions. It found no matches to four common
credential patterns in those blobs; this is not a complete secret/security audit.
The script deliberately excludes binary assets and most documentation, cannot
prove code works, and scans fetched branch tips rather than this uncommitted or
later candidate tree. An inventory is **not** manual semantic review of every
function. Binary dependencies, licences, all code paths, and historical commits
need separate review. The lists below describe triage, not proof that every
independent change is integrated.

`main-only/branch-only` counts below are commit-graph counts; commits with
similar content may have different histories. No branch is deleted or rewritten.

| Fetched branch | Tip | Main-only / branch-only | Initial decision |
| --- | --- | ---: | --- |
| `main` | `cb1e264bb951` | 0 / 0 | Existing PDF source and navigation integrated into the candidate. |
| `agent/magic-scan-20261028` | `90904cd80c80` | 4 / 21 | Candidate base; selected icon, six section identities, scan/photo/OCR work, and experimental Office preview preserved. |
| `agent/creative-studio-android` | `81e817f1595c` | 180 / 0 | Ancestor of main; preserve ref. |
| `agent/document-workflows` | `a889755fadeb` | 146 / 0 | Ancestor of main; preserve ref. |
| `integration/creative-studio-reconciled` | `aa05fa87f077` | 162 / 0 | Ancestor of main; preserve ref. |
| `engineering/office-content-editor` | `337ede383c2a` | 113 / 0 | Ancestor of main; preserve ref. |
| `integration/office-editor` | `76398449c8f5` | 111 / 0 | Ancestor of main; preserve ref. |
| `release/0.2.0-integration` | `57f21b7dcb22` | 103 / 0 | Ancestor of main; not evidence of this candidate's readiness. |
| `engineering/pdf-studio-editor` | `40ee7ad124e0` | 140 / 20 | Main has a later PDF editor/inspector implementation; candidate uses main's version plus added safety checks. Review earlier branch differences before retiring it. |
| `engineering/scan-studio-ci-fixes` | `aef9dfd6a041` | 140 / 8 | Camera recovery is cleared only after a committed draft in the candidate. Candidate has distinct bounded wait/draft-read tests and a scan→OCR test; do not replace them wholesale with the older branch tests. Both require real execution. |
| `engineering/document-workflows-phase-1` | `90e8087257d7` | 160 / 48 | Older standalone image, external-file and stamp/signature work overlaps newer flows but has not been reviewed function by function. Preserve and evaluate unique changes. |
| `engineering/engine-capability-audit` | `679f16ad51a7` | 160 / 27 | Older separate image and image-to-PDF screens overlap newer engines. Preserve and compare behavior and tests before consolidation. |
| `integration/complete-product-android-ready` | `c435ffcc51bc` | 105 / 52 | Adds stamp/signature and test/CI changes. Its Linux libsecret prerequisite is applied to candidate build definitions. Do not adopt its integration-branch packaging triggers or alternate icon wholesale. Latest listed run failed Android tests. |
| `integration/full-product-consolidation-2026-10-28` | `0d6a65d11f71` | 0 / 58 | Contains stamp/signature layers, shared media work and scan fixes, but removes main's `pdf_inspection.dart` and its tests. Do not merge wholesale; compare its unique features and tests individually. |
| `integration/pdf-studio` | `c4dfedf9e2d7` | 0 / 2 | Contains a separate PDF-combine flow, PPTX/XLSX layout code and different branding. Preserve and independently assess memory limits, fixtures/licences, device fidelity and integration; no whole-branch replacement. |

For seven conflicted Dart files outside navigation, common DartPad formatting of
`merge-base(90904cd, cb1e264)` and `cb1e264` produced identical text. Their
conflicts came from main's formatting colliding with later feature improvements;
the candidate retains the feature implementations. The remaining conflicts
were navigation/artwork and documentation: the PDF route, conversion action,
Home entry and guide action were reconciled with the selected six illustrations.
This review does not substitute for real project analysis or interaction tests.

## Independent CI observed, not initiated here

- Main `cb1e264` [run 40655142850](https://github.com/ZamCan/DeskSuite/actions/runs/40655142850): Android `flutter build apk --release` and Linux `flutter build linux --release` failed; Windows and unsigned-iOS jobs succeeded. Anonymous job logs returned HTTP 403, so the causes are **unknown**. The candidate's Linux definitions now include `libsecret-1-dev` because the lockfile brings in `flutter_secure_storage_linux`; that is a plausible prerequisite, not a demonstrated fix for either failure.
- Older main `b226257d` [run 40642887765](https://github.com/ZamCan/DeskSuite/actions/runs/40642887765) succeeded on its own snapshot only.
- `integration/complete-product-android-ready` `c435ffcc` [run 40664148186](https://github.com/ZamCan/DeskSuite/actions/runs/40664148186) failed its Android `flutter test` step; Linux, Windows and unsigned-iOS jobs passed. It is a different tree.

## Gate before one production main

1. Compare and selectively integrate independent branch features without losing
   PDF inspection, approved branding, scan recovery or existing user data.
2. On the owner's existing toolchains, run `flutter pub get`, `dart format`,
   `flutter analyze` and the **complete** Flutter unit/widget suite, including
   the new PDF, routing, search, scanner and Office tests. Diagnose failures;
   stub/lexical checks are not substitutes.
3. Build and test Android locally on real devices and offline; validate camera,
   OCR, source/destination providers, encrypted/damaged and large PDFs, real
   edits/split exports, accessibility and process recovery. Independently open
   output files. Test the native Office preview's sandbox and limits before any
   consideration of enabling it. Build desktop on appropriate hosts.
4. Audit all dependency binaries/licences, merged permissions and app identity;
   validate signed upgrade/release artifacts with the owner's signing setup.
5. Re-fetch, verify no further work arrived, and merge only a reviewed candidate
   to main when packaging/CI is explicitly permitted by the owner. Until then,
   this candidate and all remote branches remain separate.
