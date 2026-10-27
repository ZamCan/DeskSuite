# DeskSuite engineering baseline audit

**Audit date:** 2026-10-27  
**Repository:** https://github.com/ZamCan/DeskSuite  
**Audited ref:** `main` at `b2d22cb0691eab3d3e39ccdb6cb14156f0b34f4f`  
**Framework:** Flutter / Dart; Android runner present.  
**Application ID:** `com.zamcan.desksuite`.

## Verified current foundation

The active application is a modular design editor, not yet a general-purpose office suite. Existing code supports physical-size design documents, text/shape/image layers, manipulation, undo/redo, local project persistence, import/export of editable `.dsdesign` projects, and PNG plus one-page raster PDF export. The app uses a file-picker boundary and app-private project storage. Existing automated Flutter tests cover design geometry, serialization, repository behavior, exports and key widget flows.

## Capability matrix

| Capability | Verified baseline | Next action |
|---|---|---|
| Design canvas and physical dimensions | Implemented in `lib/design/` | Preserve; improve editor tools and responsive behavior |
| Local project persistence | Implemented in `lib/workspace/project_repository.dart` | Preserve and extend safely |
| PNG and raster PDF export | Implemented in `lib/printing/design_export.dart` | Keep limitations explicit; add document-oriented workflows |
| Image import into design | PNG/JPEG/WebP path exists | Add dedicated image editing and resizing engine |
| Camera capture / document scanner | Not implemented in active workflow | Add camera and scan pipeline in a later phase |
| OCR / searchable PDF | Not implemented | Select and integrate a real OCR engine |
| PDF import, page management and annotations | Not implemented | Add a PDF engine; do not describe current raster export as PDF editing |
| Stamps and drawn signatures | Phase 1 implementation added on feature branch | Add as editable design layers and test export; this is not cryptographic signing |
| DOCX/XLSX/PPTX editing | Not supported | Evaluate libraries/office engine and define honest support matrix |
| Generic external file opening | Current picker is for images and project files | Implement format-aware import/open flows and platform-safe handoff |
| Image resize/compression/format conversion | Not implemented as a dedicated workflow | Add a tested image-processing service |
| Onboarding and real-engine tutorials | Not implemented as complete guided workflows | Add after core engines exist |
| Google Drive integration | Not implemented | Optional later phase; requires OAuth configuration |
| Launcher identity | Existing resources and in-app mark exist | Audit at device resolution and refine in a later visual-identity phase |
| CI release signing | CI produces release validation artifacts without a persistent configured signing identity | Add protected persistent signing configuration before update-channel distribution |

## Engineering rules

1. Keep the current main branch intact while implementing on a reviewable feature branch.
2. Never claim a capability is complete because a UI control exists.
3. Preserve source files by default and validate generated outputs.
4. Treat visual stamps/signatures as editable artwork. They are not proof of identity and do not provide cryptographic document signing.
5. Office formats must be parsed or converted by a real engine; changing an extension is not conversion.
6. Record tests and actual CI outcomes before calling a phase complete.
