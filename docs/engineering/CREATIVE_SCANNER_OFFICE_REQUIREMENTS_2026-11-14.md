# DeskSuite Expanded Creative and Scanner Requirements — 2026-11-14

Status: PRODUCT REQUIREMENTS; NOT VERIFIED IMPLEMENTATIONS.
This addendum expands the release contract. It does not assert parity with CamScanner, Adobe Photoshop, Acrobat, Microsoft Office or any proprietary product.

## Scanner Studio
- Camera and gallery import, live preview, automatic document boundary detection with four-corner manual correction, perspective transform, crop, rotate, deskew, batch pages, reorder and undo.
- Non-destructive named filters: Original, Auto Enhance, Lightened, No Shadow, Black & White, Grayscale, Magic Color, Sharpen and Custom. Implement No Shadow with spatial illumination correction, not just a global brightness increase. Provide preview and intensity slider where appropriate.
- Exports: PNG, JPEG/JPG, WebP and multi-page PDF; selectable resolution, quality, paper size, filename, destination, and per-page versus batch export. WebP is the format; 'webpage' is not an image format.
- ID scanner: front/back capture, crop, alignment, one-page combined layout, A4/Letter or exact dimensions, image and PDF export, offline and free. Never upload ID scans without explicit consent.
- OCR: searchable PDF and text extraction only where the local OCR engine demonstrably works; identify supported languages and limitations.
- Acceptance: real photos with uneven light/shadows, skew, faint print, color documents and ID front/back. Compare saved/reopened outputs and verify dimensions, page counts and legibility.

## Photo Studio
- Non-destructive original and undo/redo; crop with aspect presets; rotate/flip; exposure, brightness, contrast, saturation, white balance, shadows/highlights, sharpen, blur and color filters.
- Resize by pixels/percent, DPI metadata where meaningful, format conversion JPEG/PNG/WebP, transparent export, metadata controls, and batch processing with cancellation.
- Background removal: real subject segmentation, transparent PNG, manual erase/restore and edge refinement; if no real offline model exists, keep feature disabled or explicitly marked experimental.
- Passport and ID photo production: adjustable sizing and positioning, neutral backgrounds, guidelines, duplicate print sheets, A4/Letter and 4x6 paper output.
- Test large images, orientation metadata, transparency, color and memory pressure on low-RAM Android devices.

## Graphic Design Studio
- Actual canvas with selectable/editable text, images, shapes and layers; arrange, duplicate, align, resize, rotate, group where supported; save an editable project and export PNG/JPEG/PDF.
- Template families: flyers, posters, business cards, certificates, invitations, social posts, menus, invoices, receipts, CVs, letterheads, ID/passport sheets, presentation covers.
- Templates must be real editable designs, not static preview cards. Original DeskSuite assets and icons; do not copy third-party proprietary UI or templates.
- Provide snapping, safe margins, paper/print dimensions, fonts and color tools. Advanced effects are post-release unless tested.

## Office productivity
- DOCX: open, preview, modify supported paragraphs, fonts, tables and images; save/reopen without silent content loss. Complex page fidelity requires comparison against a trusted reference.
- XLSX: multi-sheet navigation, cell values and types, formulas, basic formatting, freeze panes, sorting/filtering where implemented; preserve untouched sheets and formulas. Never promise full Excel compatibility without fixtures.
- PPTX: slide navigation, text/images/shapes, aspect ratio, supported edits, save/reopen and PDF export where implemented. Preserve unknown parts when possible; avoid destructive round-trip edits.
- ODT/ODS/ODP optional, not implied by Office label.
- Explicitly distinguish preview-only, edit-supported and export-supported formats in UI.

## Release tiers
P0 tomorrow: reliable existing scan/photo/PDF/file/print journeys and honest supported Office opening. ID front/back image/PDF export if verified. No fake controls.
P1: enhanced scanner filters, background removal, graphic layer editor, expanded Office editing and OCR — only promote to P0 after implementation and passing tests.
P2: full proprietary-app feature parity, advanced AI retouching, complex Excel formula recalculation and high-fidelity PowerPoint animations.

## Design
- A cohesive original premium interface with restrained light-blue accents and subtle glass effects, not cloned Adobe/CamScanner screens.
- Studio editing uses content-first canvas, compact tool rail/bottom sheet, live before/after preview, undo/redo and obvious save/export.
- Dashboard uses distinct section icons, no repeated DS logos, no walls of instructional cards, responsive Android layouts, accessible touch targets, dark/light mode and no nonfunctional CTAs.

## Verification matrix
For each named filter, file format, editor and export route, record: source fixture, supported operation, output artifact, reopened result, device, test status and known limitations. Mark as UNTESTED until exercised. No release certification without successful build, installation, signing verification and critical end-to-end checks.
