import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../image_engine/image_processing_service.dart';
import 'file_gateway.dart';

/// Offline multi-page PDF assembly from local images. This creates a new PDF;
/// it does not claim to edit or merge arbitrary existing PDFs.
class PdfStudioScreen extends StatefulWidget {
  const PdfStudioScreen({super.key, required this.files});
  final FileGateway files;

  @override
  State<PdfStudioScreen> createState() => _PdfStudioScreenState();
}

class _PdfStudioScreenState extends State<PdfStudioScreen> {
  final List<Uint8List> _pages = [];
  final ImageProcessingService _imageEngine = const ImageProcessingService();
  bool _busy = false;
  bool _fitToPage = true;
  String? _error;

  Future<void> _addPage() async {
    if (_busy || _pages.length >= 100) return;
    try {
      final bytes = await widget.files.pickImage();
      if (bytes == null || !mounted) return;
      // Normalize supported inputs to PNG so the PDF writer receives a
      // predictable embedded image format, including GIF/BMP inputs.
      final normalized = _imageEngine.rotate(source: bytes, degrees: 0, outputFormat: DeskImageFormat.png).bytes;
      if (!mounted) return;
      setState(() {
        _pages.add(normalized);
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  void _move(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _pages.length) return;
    setState(() {
      final item = _pages.removeAt(index);
      _pages.insert(target, item);
    });
  }

  Future<void> _export() async {
    if (_pages.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final document = pw.Document();
      for (final bytes in _pages) {
        final image = pw.MemoryImage(bytes);
        document.addPage(pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (context) => Center(
            child: pw.Image(image, fit: _fitToPage ? pw.BoxFit.contain : pw.BoxFit.fill),
          ),
        ));
      }
      final output = Uint8List.fromList(await document.save());
      final saved = await widget.files.save(
        name: 'desksuite-document.pdf',
        bytes: output,
        mimeType: 'application/pdf',
      );
      if (saved && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported a ${_pages.length}-page PDF.')),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('PDF & Documents', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('Assemble a multi-page PDF from images stored on your device. All processing is local.'),
        const SizedBox(height: 18),
        Wrap(spacing: 10, runSpacing: 10, children: [
          FilledButton.icon(onPressed: _busy || _pages.length >= 100 ? null : _addPage, icon: const Icon(Icons.add_photo_alternate_outlined), label: const Text('Add page image')),
          OutlinedButton.icon(onPressed: _pages.isEmpty || _busy ? null : () => setState(() => _pages.clear()), icon: const Icon(Icons.delete_sweep_outlined), label: const Text('Clear pages')),
        ]),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Fit image within A4 page'),
          subtitle: const Text('Keeps the full image visible. Turn off to fill the page and allow distortion.'),
          value: _fitToPage,
          onChanged: _busy ? null : (value) => setState(() => _fitToPage = value),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(12)), child: Text(_error!, style: TextStyle(color: scheme.onErrorContainer))),
        ],
        if (_busy) const LinearProgressIndicator(),
        const SizedBox(height: 12),
        if (_pages.isEmpty)
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
            child: const Column(children: [Icon(Icons.picture_as_pdf_outlined, size: 42), SizedBox(height: 12), Text('No pages added yet'), SizedBox(height: 4), Text('Add photos or scanned pages in the order you want them to appear.', textAlign: TextAlign.center)]),
          )
        else ...[
          Text('${_pages.length} page${_pages.length == 1 ? '' : 's'} · ordering controls', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          for (var i = 0; i < _pages.length; i++)
            Card(
              child: ListTile(
                leading: ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.memory(_pages[i], width: 52, height: 66, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox(width: 52, height: 66, child: Icon(Icons.broken_image_outlined)))),
                title: Text('Page ${i + 1}'),
                subtitle: Text('${(_pages[i].length / 1024).toStringAsFixed(1)} KB image'),
                trailing: Wrap(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(tooltip: 'Move up', onPressed: _busy || i == 0 ? null : () => _move(i, -1), icon: const Icon(Icons.arrow_upward)),
                  IconButton(tooltip: 'Move down', onPressed: _busy || i == _pages.length - 1 ? null : () => _move(i, 1), icon: const Icon(Icons.arrow_downward)),
                  IconButton(tooltip: 'Remove page', onPressed: _busy ? null : () => setState(() => _pages.removeAt(i)), icon: const Icon(Icons.close)),
                ]),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _busy ? null : _export, icon: const Icon(Icons.save_alt), label: const Text('Export multi-page PDF'))),
        ],
        const SizedBox(height: 24),
        Text('Scope: this workflow creates new PDFs from image pages. Opening, searching, annotating, reordering pages in existing PDFs, digital signatures and Office-to-PDF conversion remain separate engineering stages.', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
