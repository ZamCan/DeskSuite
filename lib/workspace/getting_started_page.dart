import 'package:flutter/material.dart';

/// Short, revisitable guides link to the real processing tools. The bundled
/// material is fictional and never replaces a user's existing files.
class GettingStartedPage extends StatelessWidget {
  const GettingStartedPage({
    super.key,
    required this.onScan,
    required this.onPhoto,
    required this.onEditableExample,
  });
  final VoidCallback onScan;
  final VoidCallback onPhoto;
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
        'Practise with fictional examples. The same local engines work on images you choose. No account is required.',
      ),
      const SizedBox(height: 20),
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
        'Scan PDFs contain images, not OCR or searchable text. A PDF reader, office-format editor, cloud sync and automatic page detection are not yet available. Export copies for backup; app-private data can be removed when the app is uninstalled.',
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
