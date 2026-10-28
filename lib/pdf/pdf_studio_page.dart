import 'dart:typed_data';

import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:flutter/material.dart';

import '../workspace/file_gateway.dart';
import 'pdf_combine.dart';
import 'pdf_inspection.dart';

// `pdfBaseName` lives with the other PDF primitives; re-exported so callers of
// this screen keep a single import.
export 'pdf_inspection.dart' show pdfBaseName;

/// Builds the editor surface for [bytes], reporting edited bytes through
/// [onSave]. Injected in tests so the screen's own open, inspect, save and
/// error paths are testable without rendering a real PDF.
typedef PdfEditorBuilder = Widget Function(
  Uint8List bytes, {
  required String documentId,
  required ValueChanged<Uint8List> onSave,
  required ValueChanged<Uint8List> onExportPages,
  required ValueChanged<List<Uint8List>> onSplitPages,
});

/// Read, edit, reorganise and export existing PDFs with an on-device engine.
///
/// The picked file is opened read-only and every export is written as a new
/// file through [FileGateway], so a user's original is never overwritten.
class PdfStudioPage extends StatefulWidget {
  const PdfStudioPage({
    super.key,
    required this.picker,
    required this.files,
    this.editorBuilder,
  });

  final DocumentPicker picker;
  final FileGateway files;

  /// Production uses the real editor; tests inject a surface they can drive.
  final PdfEditorBuilder? editorBuilder;

  @override
  State<PdfStudioPage> createState() => _PdfStudioPageState();
}

class _PdfStudioPageState extends State<PdfStudioPage> {
  Uint8List? _source;
  String? _sourceName;
  PdfInspection? _inspection;
  String? _error;
  String? _status;
  bool _busy = false;

  /// Set while the "combine PDFs" dialog is on screen, so the button cannot be
  /// pressed twice and the page can report a combine failure in its own banner.
  bool _combining = false;

  Future<void> _open() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _status = null;
    });
    try {
      final picked = await widget.picker.pickDocument();
      if (picked == null) {
        if (mounted) setState(() => _status = 'No file was chosen.');
        return;
      }
      final report = inspectPdf(picked.bytes);
      if (!mounted) return;
      setState(() {
        _source = Uint8List.fromList(picked.bytes);
        _sourceName = pdfBaseName(picked.name);
        _inspection = report;
        _status =
            'Opened read-only · ${report.pageCount} page(s) · ${report.sizeLabel}. '
            'Exports are saved as new files.';
      });
    } on PdfOpenFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not open that file: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save({
    required Uint8List bytes,
    required String suffix,
    required String kind,
  }) async {
    final name = _sourceName;
    if (name == null) return;
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _status = 'Writing $kind…';
    });
    try {
      if (!looksLikePdf(bytes)) {
        throw const PdfOpenFailure(
          'The editor returned bytes that are not a PDF, so nothing was saved.',
        );
      }
      final report = inspectPdf(bytes);
      final saved = await widget.files.save(
        name: '$name-$suffix.pdf',
        bytes: bytes,
        mimeType: 'application/pdf',
      );
      if (!mounted) return;
      setState(() {
        _status = saved
            ? '$kind written · ${report.pageCount} page(s) · ${report.sizeLabel}. '
                  'The original file was not changed.'
            : 'Export cancelled. No file was written.';
      });
    } on PdfOpenFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'The PDF could not be written: $error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Lets the user gather several PDFs and writes them out as one new file.
  Future<void> _combine() async {
    if (_busy || _combining) return;
    setState(() {
      _combining = true;
      _error = null;
      _status = null;
    });
    try {
      final sources = await showDialog<List<_PdfSource>>(
        context: context,
        builder: (context) => _CombineDialog(picker: widget.picker),
      );
      if (!mounted || sources == null) {
        if (mounted) {
          setState(() => _status = 'Combining cancelled. No file was written.');
        }
        return;
      }
      setState(() => _status = 'Combining ${sources.length} PDFs…');
      final result = combinePdfs([for (final source in sources) source.bytes]);
      final name = combinedPdfName(sources.first.name);
      final saved = await widget.files.save(
        name: name,
        bytes: result.bytes,
        mimeType: 'application/pdf',
      );
      if (!mounted) return;
      setState(() {
        _status = saved
            ? 'Combined ${result.documentCount} PDFs into $name · '
                  '${result.pageCount} page(s) · ${result.inspection.sizeLabel}. '
                  'The source files were not changed.'
            : 'Save cancelled. No combined file was written.';
      });
    } on PdfCombineFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not combine those PDFs: $error');
      }
    } finally {
      if (mounted) setState(() => _combining = false);
    }
  }

  Future<void> _close() async {
    setState(() {
      _source = null;
      _sourceName = null;
      _inspection = null;
      _error = null;
      _status = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final builder = widget.editorBuilder ?? _defaultEditor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null)
          _Banner(
            icon: Icons.error_outline,
            background: theme.colorScheme.errorContainer,
            foreground: theme.colorScheme.onErrorContainer,
            text: _error!,
            onDismiss: () => setState(() => _error = null),
          ),
        if (_status != null)
          _Banner(
            icon: Icons.info_outline,
            background: theme.colorScheme.surfaceContainerHigh,
            foreground: theme.colorScheme.onSurface,
            text: _status!,
            onDismiss: () => setState(() => _status = null),
            busy: _busy,
          ),
        Expanded(child: _source == null ? _intro(theme) : _editor(builder)),
      ],
    );
  }

  Widget _editor(PdfEditorBuilder builder) {
    final name = _sourceName ?? 'document';
    return Column(
      children: [
        _toolbar(name),
        const Divider(height: 1),
        Expanded(
          child: builder(
            _source!,
            documentId: name,
            onSave: (bytes) =>
                _save(bytes: bytes, suffix: 'edited', kind: 'Edited copy'),
            onExportPages: (bytes) =>
                _save(bytes: bytes, suffix: 'pages', kind: 'Page export'),
            onSplitPages: (documents) => _saveSplit(documents),
          ),
        ),
      ],
    );
  }

  Future<void> _saveSplit(List<Uint8List> documents) async {
    if (documents.isEmpty) return;
    // A split produces several files; save them one after another and report
    // how many were actually written instead of claiming the whole set.
    var written = 0;
    for (var i = 0; i < documents.length; i++) {
      final name = _sourceName;
      if (name == null) return;
      try {
        final saved = await widget.files.save(
          name: '$name-part-${i + 1}.pdf',
          bytes: documents[i],
          mimeType: 'application/pdf',
        );
        if (saved) written++;
      } catch (error) {
        if (mounted) {
          setState(
            () => _error =
                'Part ${i + 1} could not be written after $written part(s): $error',
          );
        }
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      _status = written == documents.length
          ? 'Split into ${documents.length} file(s). The original was not changed.'
          : 'Wrote $written of ${documents.length} file(s); the rest were cancelled.';
    });
  }

  Widget _toolbar(String name) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                _inspection == null
                    ? ''
                    : '${_inspection!.pageCount} page(s) · '
                          '${_inspection!.sizeLabel} · ${_inspection!.pageSizeLabel}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        IconButton(
          key: const Key('pdf-open-another'),
          tooltip: 'Open another PDF',
          onPressed: _busy ? null : _open,
          icon: const Icon(Icons.folder_open_outlined),
        ),
        IconButton(
          key: const Key('pdf-close'),
          tooltip: 'Close this PDF',
          onPressed: _busy ? null : _close,
          icon: const Icon(Icons.close),
        ),
      ],
    ),
  );

  Widget _intro(ThemeData theme) => ListView(
    padding: const EdgeInsets.all(22),
    children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.picture_as_pdf_outlined,
                size: 38,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 14),
              Text(
                'Work with a PDF you already have',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Open a PDF from this device to read it, reorder, rotate or '
                'delete pages, add text and ink, fill forms, split or export '
                'pages, or join several PDFs into one in the order you pick. '
                'Every result is written as a new file; the file you opened is '
                'never modified.',
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    key: const Key('pdf-open'),
                    onPressed: _busy ? null : _open,
                    icon: const Icon(Icons.folder_open_outlined),
                    label: Text(_busy ? 'Opening…' : 'Open PDF'),
                  ),
                  OutlinedButton.icon(
                    key: const Key('pdf-combine'),
                    onPressed: _busy || _combining ? null : _combine,
                    icon: const Icon(Icons.merge_type),
                    label: Text(_combining ? 'Combining…' : 'Combine PDFs'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 8),
      const Padding(
        padding: EdgeInsets.all(8),
        child: Text(
          'Processed on this device by a bundled PDF engine; nothing is '
          'uploaded. Password-protected PDFs are refused rather than guessed '
          'at, and very large or damaged files may open with fewer pages than '
          'a desktop reader shows.',
        ),
      ),
    ],
  );

  Widget _defaultEditor(
    Uint8List bytes, {
    required String documentId,
    required ValueChanged<Uint8List> onSave,
    required ValueChanged<Uint8List> onExportPages,
    required ValueChanged<List<Uint8List>> onSplitPages,
  }) => PdfEditorView(
    key: ValueKey('pdf-editor-$documentId'),
    bytes: bytes,
    onSave: onSave,
    onSaveAs: onSave,
    onExportPages: onExportPages,
    onSplitPages: onSplitPages,
  );
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.background,
    required this.foreground,
    required this.text,
    required this.onDismiss,
    this.busy = false,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final String text;
  final VoidCallback onDismiss;
  final bool busy;

  @override
  Widget build(BuildContext context) => Material(
    color: background,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
      child: Row(
        children: [
          Icon(icon, color: foreground, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(color: foreground)),
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          IconButton(
            tooltip: 'Dismiss message',
            onPressed: onDismiss,
            icon: Icon(Icons.close, size: 18, color: foreground),
          ),
        ],
      ),
    ),
  );
}

/// One PDF chosen for combining: the bytes plus the name to show and to build
/// the output file name from.
class _PdfSource {
  _PdfSource({required this.name, required this.bytes, required this.pages});
  final String name;
  final Uint8List bytes;
  final int pages;
}

/// Collects the PDFs to join. Picking is one file at a time because that is
/// what the platform picker offers on every supported device; the list, its
/// order and the page total are shown before anything is written.
class _CombineDialog extends StatefulWidget {
  const _CombineDialog({required this.picker});

  final DocumentPicker picker;

  @override
  State<_CombineDialog> createState() => _CombineDialogState();
}

class _CombineDialogState extends State<_CombineDialog> {
  final _sources = <_PdfSource>[];
  String? _error;
  bool _picking = false;

  int get _pageTotal => _sources.fold(0, (sum, source) => sum + source.pages);

  Future<void> _add() async {
    if (_picking) return;
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final picked = await widget.picker.pickDocument();
      if (!mounted) return;
      if (picked == null) {
        setState(() => _error = 'No file was chosen.');
        return;
      }
      final report = inspectPdf(picked.bytes);
      setState(() {
        _sources.add(
          _PdfSource(
            name: picked.name,
            bytes: Uint8List.fromList(picked.bytes),
            pages: report.pageCount,
          ),
        );
      });
    } on PdfOpenFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not read that file: $error');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Combine PDFs'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add two or more PDFs. They are joined in the order shown, and '
              'the result is saved as one new file.',
            ),
            const SizedBox(height: 12),
            if (_sources.isEmpty)
              Text(
                'No PDFs added yet.',
                key: const Key('combine-empty'),
                style: theme.textTheme.bodySmall,
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _sources.length,
                  itemBuilder: (context, index) {
                    final source = _sources[index];
                    return ListTile(
                      key: Key('combine-row-$index'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: const Icon(Icons.picture_as_pdf_outlined),
                      title: Text(
                        source.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text('${source.pages} page(s)'),
                      trailing: IconButton(
                        key: Key('combine-remove-$index'),
                        tooltip: 'Remove ${source.name}',
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () =>
                            setState(() => _sources.removeAt(index)),
                      ),
                    );
                  },
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                key: const Key('combine-error'),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              _sources.isEmpty
                  ? 'Total: 0 page(s)'
                  : '${_sources.length} file(s) · $_pageTotal page(s)',
              key: const Key('combine-total'),
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('combine-cancel'),
          onPressed: _picking ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton.icon(
          key: const Key('combine-add'),
          onPressed: _picking ? null : _add,
          icon: const Icon(Icons.add),
          label: Text(_picking ? 'Choosing…' : 'Add PDF'),
        ),
        FilledButton(
          key: const Key('combine-save'),
          onPressed: _sources.length < 2
              ? null
              : () => Navigator.of(context).pop(_sources),
          child: const Text('Combine & save'),
        ),
      ],
    );
  }
}
