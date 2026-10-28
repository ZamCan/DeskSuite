# Starter templates and practice packs

Updated 2026-10-28. This is an implemented source slice, not a signed or
device-verified release. See [validation](VALIDATION.md) and the
[master directive](MASTER_ENGINEERING_DIRECTIVE.md).

## Where to find them

- **Creative Studio → ID badge templates** opens the existing design-creation
  dialog. Its template list includes fictional staff, member and event layouts.
  Select the coloured photo area (or **Photo placeholder** from **Layers**),
  choose **Edit object → Fill photo slot with image**, and edit text/objects in
  the same saved `.dsdesign` project as other designs.
  The image is locally decoded before replacement, embedded as a layer, and
  cover-fitted; its edges can be cropped. Undo/redo and project serialization
  use the existing design model. These examples are neither official IDs nor
  photo/biometric compliance checks. Verify all real-world requirements and
  print scaling independently.
- **Document converter → Browse templates & samples** offers two original
  DOCX documents, two XLSX workbooks and two wide PPTX slide decks. The new
  **Save unchanged template** action sends the exact bundled bytes and correct
  MIME type to the platform save dialog. It does not edit or re-encode the
  template. Choose a new name/location to avoid overwriting another file.
  Compatible external Office apps can edit the original layout, formulas and
  PPTX shapes; compatibility and rendering in those apps must be checked.
- **Photo Studio → Try a studio still life** opens the generated example via
  the normal bounded photo processor. Crop, rotate, resize, compare and export
  are real existing operations; choosing another image asks before discarding
  a working copy. The 1200 × 896 fictional image was generated for this project,
  not taken from a person or customer file. The noisy garden and previous photo
  samples remain available.
- **Scan & assemble → Try an example** includes the existing one-page and
  two-page examples, a three-page office pack (letter, invoice and form), and a
  three-page cleanup/corner pack (clean, shadowed and angled practice pages).
  Sample pages are processed first, checked as a group, and only then appended
  to the existing draft. A preflight rejects page-count overflow; total pixel and
  byte checks still run. The usual private draft persistence/retry and image-PDF
  workflow apply. If persistence fails, the pages remain only in memory until
  retry/export; do not close before saving them.

## Office and design boundaries

`office_template_catalog.dart` identifies the bundled files, not fake legacy
formats. `tools/generate_office_templates.py` builds the DOCX with
`python-docx`, XLSX with `openpyxl`, and original editable slide XML/shapes using
this repository's project-generated fictional PPTX test fixture as a scaffold.
The output uses fixed ZIP/core timestamps for reproducibility. Project-authored
text and source are covered by the repository licence; the generated still life
is documented separately above. No external customer or upstream sample file is
bundled. Workbooks have live example formulas in the **unchanged original**;
recalculate/review them in a compatible spreadsheet application.

DeskSuite's in-app Office editor is a **content extractor/editor**, not a
layout-faithful renderer or round-trip editor. It emits simplified copies;
styles, images, charts, formulas and complex layout are not preserved. The
reader uses cached formula results when present and displays an uncached
formula as text; it does not calculate formulas. It cannot export edited PPTX
slides. Normal builds cannot convert legacy DOC, XLS or PPT. The separately
bundled C++/WASM original-layout preview is read-only, disabled by default and
unverified on Android; it does not provide conversion or slide editing. No
legacy file is manufactured by giving OOXML a `.doc`, `.xls` or `.ppt` name.

Marked ID photo slots store a reserved marker in the existing rectangle `text`
field, avoiding a project schema change. Existing saved projects remain
readable. An old 35 × 45 mm print-sheet slot is still recognized by its prior
geometry/label convention. Ordinary rectangles are rejected. Replacing a new
marked slot never deletes overlapping user artwork; the older slot retains its
original label-removal behavior. Image decoding, UI, Android picker, export and
printer behavior still require real Flutter/device validation.

## Regenerate and check (host tools)

```sh
python3 tools/generate_office_templates.py     # python-docx and openpyxl
python3 tools/test_office_template_assets.py    # plus Pillow
python3 tools/test_office_template_save_flow.py  # existing Dart; fake gateway
python3 tools/test_id_photo_fill_flow.py         # existing Dart; fake picker/decoder
python3 tools/test_scan_sample_flow.py           # existing Dart; fake codec/store
node tools/test_office_renderer.mjs              # actual packaged WASM/worker
```

`test/office_templates_test.dart`, `test/office_convert_page_test.dart`,
`test/photo_print_slot_test.dart`, `test/id_template_inspector_test.dart`,
`test/photo_widget_test.dart` and `test/scan_studio_widget_test.dart` add real
Flutter/model/widget coverage. They have been written but have **not** run in
this workspace. On the owner's existing Flutter toolchain run these and the
complete suite, then verify native save providers, photo input, scan-draft
recovery, accessibility, Office compatibility, low-memory behavior and
printing on real devices. See the validation record for precisely what host
and stub checks were actually executed.
