/// Bundled fictional starter files. They are original OOXML documents, not
/// renamed legacy binaries. A saved original is byte-for-byte the bundled file;
/// DeskSuite's separate content editor does not preserve complete layout.
enum OfficeTemplateKind { word, spreadsheet, presentation }

class OfficeTemplateDefinition {
  const OfficeTemplateDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.fileName,
    required this.kind,
  });

  final String id;
  final String title;
  final String description;
  final String fileName;
  final OfficeTemplateKind kind;

  String get assetPath => 'assets/samples/office_templates/$fileName';
  String get mimeType => switch (kind) {
    OfficeTemplateKind.word =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    OfficeTemplateKind.spreadsheet =>
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    OfficeTemplateKind.presentation => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  };
}

const officeTemplateCatalog = <OfficeTemplateDefinition>[
  OfficeTemplateDefinition(
    id: 'professional-letter',
    title: 'Professional letter · DOCX',
    description:
        'Branded letter structure with editable recipient and message.',
    fileName: 'professional-letter.docx',
    kind: OfficeTemplateKind.word,
  ),
  OfficeTemplateDefinition(
    id: 'project-brief',
    title: 'Project brief · DOCX',
    description: 'Editable objectives, scope, milestones and next steps.',
    fileName: 'project-brief.docx',
    kind: OfficeTemplateKind.word,
  ),
  OfficeTemplateDefinition(
    id: 'monthly-budget',
    title: 'Monthly budget · XLSX',
    description: 'Sample planned and actual amounts, with variance formulas.',
    fileName: 'monthly-budget.xlsx',
    kind: OfficeTemplateKind.spreadsheet,
  ),
  OfficeTemplateDefinition(
    id: 'stock-tracker',
    title: 'Stock tracker · XLSX',
    description: 'Fictional inventory rows with quantity and value formulas.',
    fileName: 'stock-tracker.xlsx',
    kind: OfficeTemplateKind.spreadsheet,
  ),
  OfficeTemplateDefinition(
    id: 'project-pitch',
    title: 'Project pitch · PPTX',
    description: 'Four wide slides with editable text and shapes.',
    fileName: 'project-pitch.pptx',
    kind: OfficeTemplateKind.presentation,
  ),
  OfficeTemplateDefinition(
    id: 'workshop-lesson',
    title: 'Workshop lesson · PPTX',
    description: 'Three wide slides with editable text and shapes.',
    fileName: 'workshop-lesson.pptx',
    kind: OfficeTemplateKind.presentation,
  ),
];
