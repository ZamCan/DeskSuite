import 'package:flutter/material.dart';

/// Short, revisitable guides link to the real processing tools. The bundled
/// material is fictional and never replaces a user's existing files.
class GettingStartedPage extends StatelessWidget {
  const GettingStartedPage({
    super.key,
    required this.onScan,
    required this.onPhoto,
    required this.onText,
    required this.onOffice,
    required this.onEditableExample,
  });
  final VoidCallback onScan;
  final VoidCallback onPhoto;
  final VoidCallback onText;
  final VoidCallback onOffice;
  final VoidCallback onEditableExample;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
    children: [
      Text(
        'Getting started',
        style: Theme.of(context).textTheme.headlineSmall
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      const Text(
        'Practise with fictional examples before working on your own files. No account is required.',
      ),
      const SizedBox(height: 20),
      _GuideCard(
        key: const Key('guide-extract-text'),
        icon: Icons.text_snippet_outlined,
        title: 'Extract text from a scan',
        description:
            'In Text extraction, choose an image or the sample letter, run the '
            'built-in text recognizer, correct the words, then save TXT, DOCX or a '
            'searchable PDF. Tables and handwriting are not reconstructed.',
        button: 'Open text extraction',
        onPressed: onText,
      ),
      const SizedBox(height: 12),
      _GuideCard(
        key: const Key('guide-convert-office'),
        icon: Icons.sync_alt_rounded,
        title: 'Convert an office document',
        description:
            'In Document converter, open a DOCX, XLSX, PPTX, ODT, ODS, ODP or '
            'RTF file and save a PDF, text, CSV or OpenDocument copy. Each route '
            'states what is preserved and what is lost.',
        button: 'Open document converter',
        onPressed: onOffice,
      ),
      const SizedBox(height: 12),
      _GuideCard(
        icon: Icons.auto_fix_high,
        title: 'Clean a shadowed page',
        description: 'In Scan & assemble, choose Try an example → Shadowed field notes → Clean up & compare. Preview reduced uneven lighting, switch between Before and After, then try adaptive black & white. Use the result only after reviewing the text and colored chart; export a new PNG or image PDF.',
        button: 'Practise document cleanup',
        onPressed: onScan,
      ),
      const SizedBox(height: 12),
      _GuideCard(
        icon: Icons.document_scanner_outlined,
        title: 'Make a multipage image PDF',
        description: 'Open Scan & assemble, choose Try an example → Two-page report, reorder the pages and select Prepare PDF. Choose a new destination and open the PDF to check it.',
        button: 'Open scan workspace',
        onPressed: onScan,
      ),
      const SizedBox(height: 12),
      _GuideCard(
        icon: Icons.crop_free,
        title: 'Correct a perspective page',
        description: 'Choose the perspective letter example in Scan & assemble, select A4 portrait proportions, and move the four handles onto the paper corners. Correct the page and compare it with Reset page. Detection is manual.',
        button: 'Practise page correction',
        onPressed: onScan,
      ),
      const SizedBox(height: 12),
      _GuideCard(
        icon: Icons.filter_center_focus,
        title: 'Reduce photo specks',
        description: 'In Photo Studio, choose Try a noisy garden photo, then Reduce isolated specks. Pinch to inspect the detail, choose Compare original, and use Undo if needed. The filter targets isolated black or white dots; it cannot remove blur or scratches and may soften fine details. Export a separate copy.',
        button: 'Practise photo cleanup',
        onPressed: onPhoto,
      ),
      const SizedBox(height: 12),
      _GuideCard(
        icon: Icons.photo_size_select_large_outlined,
        title: 'Resize an image',
        description: 'In Photo Studio, choose Try a sample image → Resize. Enter 512 pixels for width, keep the aspect ratio, then export and review the actual dimensions and encoded file size.',
        button: 'Open Photo Studio',
        onPressed: onPhoto,
      ),
      const SizedBox(height: 12),
      _GuideCard(
        icon: Icons.edit_document,
        title: 'Edit an example design',
        description: 'Open an editable fictional letter as a new DeskSuite design copy. Its text objects can be edited in Creative Studio; it is not a DOCX or a word-processing document.',
        button: 'Open editable example',
        onPressed: onEditableExample,
      ),
      const SizedBox(height: 20),
      Text('Important limits', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      const Text(
        'Scan PDFs contain page images, not selectable or searchable OCR text. PDF Studio opens supported existing PDFs and saves edits as a separate copy. Office conversion preserves supported content rather than every original layout detail. Page-corner suggestions must be reviewed and corrected before export. Export important work before uninstalling because app-private files may be removed.',
      ),
      const SizedBox(height: 8),
      const Text(
        'The practice photograph is synthetic. The forms, names and invoices are fictional and are not official documents.',
      ),
    ],
  );
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.button,
    required this.onPressed,
  });
  final IconData icon;
  final String title, description, button;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(description),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: onPressed, child: Text(button)),
        ],
      ),
    ),
  );
}
