import '../core/ids.dart';
import 'design_document.dart';

/// Reusable, editable starting layouts. Templates produce ordinary
/// DesignElements so every layout uses the same editor, renderer and exporter.
const int designTemplateCatalogVersion = 1;

enum DesignTemplate {
  blank,
  editorial,
  businessCard,
  identityBadge,
  certificate,
  flyer,
  photoPrintSheet,
  presentationCover,
}

class DesignTemplateDefinition {
  const DesignTemplateDefinition({
    required this.id,
    required this.label,
    required this.description,
    required this.widthMm,
    required this.heightMm,
    required this.template,
    this.schemaVersion = designTemplateCatalogVersion,
    this.source = 'DeskSuite original starter layout',
    this.license = 'Apache-2.0 (repository licence)',
  });

  final String id;
  final String label;
  final String description;
  final double widthMm;
  final double heightMm;
  final DesignTemplate template;
  final int schemaVersion;
  final String source;
  final String license;
}

const designTemplateCatalog = <DesignTemplateDefinition>[
  DesignTemplateDefinition(
    id: 'blank',
    label: 'Blank canvas',
    description: 'Start from a clean page and add your own objects.',
    widthMm: 210,
    heightMm: 297,
    template: DesignTemplate.blank,
  ),
  DesignTemplateDefinition(
    id: 'editorial-poster',
    label: 'Editorial poster',
    description: 'Bold headline, supporting copy and a warm colour block.',
    widthMm: 210,
    heightMm: 297,
    template: DesignTemplate.editorial,
  ),
  DesignTemplateDefinition(
    id: 'business-card',
    label: 'Business card',
    description: 'Compact contact card with editable brand and details.',
    widthMm: 85,
    heightMm: 55,
    template: DesignTemplate.businessCard,
  ),
  DesignTemplateDefinition(
    id: 'identity-badge',
    label: 'Identity badge',
    description: 'Portrait badge layout with name, role and ID placeholder.',
    widthMm: 54,
    heightMm: 86,
    template: DesignTemplate.identityBadge,
  ),
  DesignTemplateDefinition(
    id: 'certificate',
    label: 'Certificate',
    description:
        'Landscape certificate with title, recipient and signature lines.',
    widthMm: 297,
    heightMm: 210,
    template: DesignTemplate.certificate,
  ),
  DesignTemplateDefinition(
    id: 'flyer',
    label: 'Flyer',
    description: 'A4 announcement layout for events, offers and notices.',
    widthMm: 210,
    heightMm: 297,
    template: DesignTemplate.flyer,
  ),
  DesignTemplateDefinition(
    id: 'photo-print-sheet',
    label: 'A4 multi-photo layout example',
    description: 'An editable A4 layout with twenty 35 × 45 mm example slots. One paper/layout option only—not a passport standard or universal photo size.',
    widthMm: 210,
    heightMm: 297,
    template: DesignTemplate.photoPrintSheet,
  ),
  DesignTemplateDefinition(
    id: 'presentation-cover',
    label: 'Presentation cover',
    description: 'Wide title slide that can be edited and exported as a page.',
    widthMm: 338.7,
    heightMm: 190.5,
    template: DesignTemplate.presentationCover,
  ),
];

DesignTemplateDefinition designTemplateDefinition(DesignTemplate template) =>
    designTemplateCatalog.firstWhere((item) => item.template == template);

List<DesignElement> buildDesignTemplateElements(
  DesignTemplate template, {
  required double widthMm,
  required double heightMm,
}) {
  if (!widthMm.isFinite ||
      !heightMm.isFinite ||
      widthMm < 10 ||
      heightMm < 10 ||
      widthMm > 1200 ||
      heightMm > 1200) {
    throw const FormatException(
      'Template dimensions must be between 10 and 1200 mm.',
    );
  }
  if (template == DesignTemplate.blank) return const [];
  final w = widthMm;
  final h = heightMm;

  DesignElement rect(
    double x,
    double y,
    double width,
    double height,
    int color,
  ) {
    final safeX = x.clamp(0.0, w - 1).toDouble();
    final safeY = y.clamp(0.0, h - 1).toDouble();
    return DesignElement(
      id: newId(),
      kind: ElementKind.rectangle,
      x: safeX,
      y: safeY,
      width: width.clamp(1.0, w - safeX).toDouble(),
      height: height.clamp(1.0, h - safeY).toDouble(),
      color: color,
    );
  }

  DesignElement text(
    String value,
    double x,
    double y,
    double width,
    double height, {
    double size = 18,
    int color = 0xff292722,
    bool bold = false,
    TextAlignment alignment = TextAlignment.left,
  }) {
    final safeX = x.clamp(0.0, w - 1).toDouble();
    final safeY = y.clamp(0.0, h - 1).toDouble();
    return DesignElement(
      id: newId(),
      kind: ElementKind.text,
      x: safeX,
      y: safeY,
      width: width.clamp(1.0, w - safeX).toDouble(),
      height: height.clamp(1.0, h - safeY).toDouble(),
      text: value,
      fontSizePt: size.clamp(4, 500).toDouble(),
      color: color,
      bold: bold,
      textAlignment: alignment,
    );
  }

  switch (template) {
    case DesignTemplate.blank:
      return const [];
    case DesignTemplate.editorial:
      return [
        rect(0, 0, w, h * .34, 0xffbd694f),
        text(
          'YOUR\nHEADLINE',
          w * .08,
          h * .42,
          w * .84,
          h * .18,
          size: w * .19,
          bold: true,
        ),
        text(
          'Add your details here.',
          w * .08,
          h * .72,
          w * .78,
          h * .12,
          size: w * .065,
        ),
      ];
    case DesignTemplate.businessCard:
      return [
        rect(0, 0, w * .12, h, 0xffbd694f),
        text(
          'YOUR BRAND',
          w * .2,
          h * .16,
          w * .74,
          h * .2,
          size: w * .105,
          bold: true,
        ),
        text(
          'Name / Position',
          w * .2,
          h * .45,
          w * .74,
          h * .15,
          size: w * .065,
        ),
        text(
          'phone · email · website',
          w * .2,
          h * .68,
          w * .74,
          h * .2,
          size: w * .045,
        ),
      ];
    case DesignTemplate.identityBadge:
      return [
        rect(0, 0, w, h * .22, 0xffbd694f),
        text(
          'ORGANISATION',
          w * .08,
          h * .07,
          w * .84,
          h * .1,
          size: w * .095,
          color: 0xffffffff,
          bold: true,
          alignment: TextAlignment.center,
        ),
        rect(w * .3, h * .29, w * .4, h * .26, 0xffe8e1d5),
        text(
          'FULL NAME',
          w * .08,
          h * .61,
          w * .84,
          h * .1,
          size: w * .095,
          bold: true,
          alignment: TextAlignment.center,
        ),
        text(
          'Role · ID number',
          w * .08,
          h * .73,
          w * .84,
          h * .08,
          size: w * .065,
          alignment: TextAlignment.center,
        ),
        text(
          'VALID UNTIL',
          w * .08,
          h * .87,
          w * .84,
          h * .06,
          size: w * .045,
          alignment: TextAlignment.center,
        ),
      ];
    case DesignTemplate.certificate:
      return [
        rect(5, 5, w - 10, h - 10, 0xffe9dfcc),
        rect(9, 9, w - 18, h - 18, 0xffffffff),
        text(
          'CERTIFICATE',
          w * .1,
          h * .18,
          w * .8,
          h * .15,
          size: w * .11,
          color: 0xff8c5139,
          bold: true,
          alignment: TextAlignment.center,
        ),
        text(
          'OF ACHIEVEMENT',
          w * .1,
          h * .33,
          w * .8,
          h * .1,
          size: w * .055,
          bold: true,
          alignment: TextAlignment.center,
        ),
        text(
          'Presented to',
          w * .1,
          h * .49,
          w * .8,
          h * .07,
          size: w * .04,
          alignment: TextAlignment.center,
        ),
        text(
          'RECIPIENT NAME',
          w * .1,
          h * .57,
          w * .8,
          h * .12,
          size: w * .075,
          bold: true,
          alignment: TextAlignment.center,
        ),
        text(
          'For outstanding contribution',
          w * .1,
          h * .7,
          w * .8,
          h * .07,
          size: w * .035,
          alignment: TextAlignment.center,
        ),
        text(
          'Date __________     Signature __________',
          w * .1,
          h * .82,
          w * .8,
          h * .07,
          size: w * .03,
          alignment: TextAlignment.center,
        ),
      ];
    case DesignTemplate.flyer:
      return [
        rect(0, 0, w, h * .26, 0xffbd694f),
        text(
          'EVENT / OFFER',
          w * .07,
          h * .07,
          w * .86,
          h * .13,
          size: w * .105,
          color: 0xffffffff,
          bold: true,
        ),
        text(
          'A clear, memorable headline',
          w * .07,
          h * .34,
          w * .86,
          h * .15,
          size: w * .075,
          bold: true,
        ),
        text(
          'Describe what is happening, who it is for and why people should care.',
          w * .07,
          h * .52,
          w * .84,
          h * .18,
          size: w * .045,
        ),
        rect(w * .07, h * .76, w * .55, h * .11, 0xff292722),
        text(
          'DATE · TIME · PLACE',
          w * .09,
          h * .785,
          w * .51,
          h * .055,
          size: w * .035,
          color: 0xffffffff,
          bold: true,
        ),
        text(
          'Contact / registration details',
          w * .07,
          h * .9,
          w * .86,
          h * .06,
          size: w * .035,
        ),
      ];
    case DesignTemplate.photoPrintSheet:
      // Twenty editable placeholders for a practical A4 layout. These are
      // ordinary shapes/text, not image frames and not authority-certified IDs.
      final elements = <DesignElement>[
        text(
          'A4 MULTI-PHOTO LAYOUT EXAMPLE',
          10,
          5,
          w - 20,
          10,
          size: 5,
          bold: true,
        ),
        text(
          'Example only · verify photo spec, media and scale',
          10,
          16,
          w - 20,
          7,
          size: 3.5,
          color: 0xff777970,
        ),
      ];
      const columns = 4;
      const rows = 5;
      const photoWidth = 35.0;
      const photoHeight = 45.0;
      const gapX = 4.0;
      const gapY = 5.0;
      final gridWidth = columns * photoWidth + (columns - 1) * gapX;
      final startX = (w - gridWidth) / 2;
      const startY = 29.0;
      for (var row = 0; row < rows; row++) {
        for (var column = 0; column < columns; column++) {
          final x = startX + column * (photoWidth + gapX);
          final y = startY + row * (photoHeight + gapY);
          elements
            ..add(rect(x, y, photoWidth, photoHeight, 0xffe8e1d5))
            ..add(
              text(
                'PHOTO\n35 × 45 mm',
                x + 1,
                y + 17,
                photoWidth - 2,
                12,
                size: 4.5,
                alignment: TextAlignment.center,
              ),
            );
        }
      }
      elements.add(
        text(
          'Cut carefully · print at 100% scale',
          10,
          279,
          w - 20,
          8,
          size: 3.5,
          color: 0xff777970,
        ),
      );
      return elements;
    case DesignTemplate.presentationCover:
      return [
        rect(0, 0, w * .34, h, 0xffbd694f),
        rect(w * .34, 0, w * .66, h, 0xfff7f5ef),
        text(
          'PRESENTATION TITLE',
          w * .42,
          h * .24,
          w * .52,
          h * .28,
          size: w * .075,
          bold: true,
        ),
        text(
          'Subtitle or project description',
          w * .42,
          h * .56,
          w * .5,
          h * .15,
          size: w * .035,
        ),
        text(
          'AUTHOR · DATE',
          w * .42,
          h * .79,
          w * .5,
          h * .08,
          size: w * .028,
          color: 0xff777970,
        ),
      ];
  }
}
