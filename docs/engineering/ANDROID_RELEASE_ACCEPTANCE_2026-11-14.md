# DeskSuite Android — Release Acceptance Contract

**Target:** 14 November 2026 (Africa/Dar_es_Salaam)
**Branch:** main
**Status:** REQUIREMENTS FROZEN; NOT YET VERIFIED OR CERTIFIED
**Rule:** Code presence, screenshots and a successful APK build are not proof that an engine works.

## Release priority
P0: application starts, local workspace/file lifecycle, scanner-to-PDF, PDF viewing and manipulation, photo processing, printing/export, safe supported Office open/save, privacy and crash safety.
P1: advanced OCR, broad Office fidelity, image background removal, advanced annotations, complex formula/slideshow editing. Include only when demonstrably functional; otherwise hide or label limitations honestly.
P2: cross-platform support, cloud collaboration, AI services and elaborate animations; excluded from this Android release.

## Engine acceptance — executable end-to-end journeys
Each P0 journey must be tested with real files on a device and automated where feasible. Record source, expected output, actual output, and defects.

1. **Workspace and file operations:** import via Android Storage Access Framework / picker; list and preview; rename, copy, move, delete with confirmation; reopen after process restart; share/export using valid URI permissions. No destructive operation without confirmation. Do not assume unrestricted filesystem access.
2. **Scanner:** import or capture a real page; detect or manually set four corners; perspective-correct, crop, rotate, enhance; add/reorder/remove pages; export multi-page PDF; reopen exported PDF and visually compare. If camera capture is not integrated, disable the camera CTA rather than simulate capture.
3. **PDF Studio:** open a real multi-page PDF; render page thumbnails and full page; rotate, reorder, remove, split, merge and extract; save to a new file; reopen and verify exact page count, order and orientation. Preserve source until explicit overwrite. Encryption, signature, annotations and compression are NOT certified without separate tests.
4. **Photo Studio:** import JPEG/PNG/WebP; crop, rotate, flip, resize by dimensions, basic adjustments and format conversion; save and reopen; verify dimensions and output encoding. Test EXIF orientation and memory behavior on large images. Background removal and portrait enhancement are optional unless real engines pass.
5. **Print production:** choose A4/Letter and photo-sheet layouts, correct aspect ratio, margins, print preview, export PDF, and launch Android print/share. Confirm printed/exported dimensions with physical or PDF measurement.
6. **Office:** DOCX, XLSX and PPTX must open supported sample files and preserve content after supported edits and save/reopen. Run tests for paragraphs, Unicode, tables, cell values/formulas, slides and embedded media. Complex layout or formula fidelity is not guaranteed: explicitly limit, disable or label unsupported editing rather than silently corrupt files.
7. **Navigation and UX:** every visible tool action reaches a working workflow; back navigation, cancellation, loading and errors work; no sample-only buttons masquerading as features; no meaningless repeated DS iconography.
8. **Offline:** repeat P0 workflows with airplane mode enabled; no network needed for core local operations. Any online-only capability must be identified and optional.
9. **Safety and privacy:** no data loss on cancellation, interruption or failed export; temporary files cleaned safely; scoped storage/URI permissions; no sensitive document contents in logs; no silent uploads.
10. **Startup:** Android system splash followed by a brief DeskSuite wordmark animation, then official brand logo and workspace; reduced motion honored; no falling icons or welcome copy; no prolonged blank frame or forced delay beyond readiness requirements.

## Visual design acceptance
- Consistent shared tokens for light/dark palettes; restrained pale-blue accents for studio affordances rather than saturated backgrounds; do not change every screen's colors independently.
- Legible contrast, 48dp-equivalent touch targets where practical, text scaling, TalkBack semantics, safe-area and keyboard handling.
- Each section has a distinct, meaningful icon. Official logo only for brand surfaces, not as a substitute for every tool icon.
- Genuine workspace-first layout: compact toolbar, canvas/preview/content area, contextual controls, clear primary action, concise empty/error states.
- Avoid web-style walls of explanatory cards, decorative glass overload, fake progress, repeated CTAs, overflowing controls and unnecessary scroll on primary dashboards.
- Respect small phones, landscape, system font scaling and Android back navigation.
- Preserve source documents and provide visible save/export completion or actionable errors.

## Evidence gates
**G0 — Source:** clean main branch and reviewed changes; no release-blocking TODO/placeholder routes.
**G1 — Static:** flutter pub get; flutter analyze; no analyzer errors.
**G2 — Automated:** flutter test passes; add engine fixture-based tests and startup tests; log results.
**G3 — Build:** flutter build apk --release succeeds; archive exact SHA/version/artifact; distinguish unsigned verification artifacts from signed releases.
**G4 — Device:** install and launch on Android device; execute all P0 journeys including offline and permission-denied cases; record model/OS and pass/fail.
**G5 — Distribution:** sign with the existing owner-controlled keystore; verify signature with apksigner; test upgrade path and installation; never commit keystore or passwords.
**G6 — Release decision:** zero unresolved P0 defects; documented P1 limitations; owner approves candidate. Only then classify as PRODUCTION READY.

## Reporting
For every engine report: IMPLEMENTED / TESTED PASS / TESTED FAIL / LIMITED / NOT TESTED, with evidence link, fixture and device details. Do not mark an engine verified based on source inspection alone.

## Deadline triage
If a P0 workflow fails: fix and retest; if impossible by deadline, explicitly reduce release scope and remove misleading controls. Never call a build production-ready simply to meet the date.
