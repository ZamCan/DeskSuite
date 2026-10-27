/// Explicit, bounded conversion routes. A null target is intentionally not
/// actionable; the catalogue must never imply an unavailable engine exists.
enum ConversionTarget { photos, scans, projects, design, notes }

class ConversionRoute {
  const ConversionRoute({
    required this.title,
    required this.detail,
    this.target,
  });

  final String title;
  final String detail;
  final ConversionTarget? target;
  bool get available => target != null;
}

const conversionRoutes = <ConversionRoute>[
  ConversionRoute(
    title: 'PNG, JPEG or WebP → PNG or JPEG',
    detail: 'Photo Studio re-encodes the first frame. Resize and review the output before choosing a separate file. JPEG uses a white background for transparency.',
    target: ConversionTarget.photos,
  ),
  ConversionRoute(
    title: 'Images → multipage image PDF',
    detail: 'Scan & assemble accepts up to eight images and places them in order on A4 or Letter pages. The PDF is not searchable.',
    target: ConversionTarget.scans,
  ),
  ConversionRoute(
    title: 'Earlier .dsproject → editable .dsdesign',
    detail: 'Import a supported earlier project as a new copy in Files & Projects. Unsupported or oversized content is rejected.',
    target: ConversionTarget.projects,
  ),
  ConversionRoute(
    title: 'Editable .dsdesign → PNG or image PDF',
    detail: 'Open a design in Creative Studio and export a flattened copy. PDF text is not selectable.',
    target: ConversionTarget.design,
  ),
  ConversionRoute(
    title: 'Office Notes → plain TXT',
    detail: 'Export the local note as a UTF-8 text copy. This is not extraction from an arbitrary document.',
    target: ConversionTarget.notes,
  ),
  ConversionRoute(
    title: 'Images or PDFs → extracted text / searchable PDF',
    detail: 'Unavailable: an OCR engine and a searchable text layer have not been integrated.',
  ),
  ConversionRoute(
    title: 'Existing PDF → images, edited pages or compressed PDF',
    detail: 'Unavailable: DeskSuite does not import or modify existing PDFs.',
  ),
  ConversionRoute(
    title: 'DOCX, XLSX, PPTX and other office conversions',
    detail:
        'Unavailable: there is no Office document import or conversion engine.',
  ),
];
