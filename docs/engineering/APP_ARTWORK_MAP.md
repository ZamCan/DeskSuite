# DeskSuite artwork → actual application positions

The approved app logo is `DeskSuite-scan-frame-choice.png`, preserved as
`assets/brand/desksuite-icon-source.png`. Its derived `desksuite-mark.png` is
used in startup, Home, the navigation brand, welcome and guide. Android launcher
resources and desktop icon assets are derived from the same source. Earlier
candidates below are **section artwork only**, not alternative launcher logos.

The following table describes the real source in this feature branch, not a
mockup. Each Home card's `WorkspaceSection` determines both the navigation
callback and the illustration. The same section-to-art map drives the matching
navigation-row image and section title-bar image. Pages are chosen by the
exhaustive `_sectionPage` switch in `lib/workspace/workspace_screen.dart`.

| Home card / key | Navigation destination | Actual page | Artwork (earlier candidate) | Matching guide actions |
| --- | --- | --- | --- | --- |
| Scan documents / `home-open-scan` | Scan & assemble | `ScanStudioPage` in `lib/document_scan/scan_studio_page.dart` | `scan.png` — `01-sapphire-scan.png` | Page cleanup, multipage PDF, perspective correction |
| Work with a PDF / `home-open-pdf` | PDF & Documents | `PdfStudioPage` in `lib/pdf/pdf_studio_page.dart` | Standard PDF icon; no additional app logo | Work with an existing PDF |
| Edit a photo / `home-open-photo` | Photo Studio | `PhotoPage` in `lib/legacy_studios.dart` | `photo.png` — `03-indigo-orbit.png` | Photo speck cleanup and resize |
| Extract text / `home-open-text` | Text extraction | `TextExtractionPage` in `lib/ocr/text_extraction_page.dart` | `text.png` — `DeskSuite-symbolic-logo.png` | Extract text from a scan |
| Convert file / `home-open-converter` | Document converter | `OfficeConvertPage` in `lib/office/office_convert_page.dart` | `office.png` — `DeskSuite-scan-frame-alternative.png` | Convert an office document |
| Creative Studio / `home-open-design` | Creative Studio | `CreativeStudioPage` in `lib/workspace/creative_studio_page.dart` | `design.png` — `DeskSuite-creative-suite-icon.png` with ruler/pencil | The editable-example guide opens a new copy in the design editor |
| Files & Projects / `home-open-projects` | Files & Projects | `_projectPage` in `lib/workspace/workspace_screen.dart` | `projects.png` — `02-emerald-stack.png` | No separate guide card |

Other navigation items keep their own appropriate standard icons; artwork does
not imply extra functionality. The Guide and Home retain the selected primary
logo. In this isolated integration candidate, `PDF & Documents` uses the real
PDF page imported from `main`; its Home and guide entries use a standard icon.
Home's search filters only the seven real shortcuts and does not search files.
Flutter, PDF-rendering and device behavior remain unverified.

`tools/test_brand_assets.py` checks the selected logo assets, six source-image
hashes, Home/card/section/guide mappings, exhaustive page cases and desktop
icon frames on the host. With an existing Dart SDK,
`python3 tools/test_workspace_routing.py` runs the actual section/art switch
with UI stubs. Flutter widget tests cover the actual Home, drawer and
guide interactions but have not been run in this workspace; native launcher,
small-screen layout and real device appearances remain unverified.
