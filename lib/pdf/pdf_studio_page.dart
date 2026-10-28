import 'dart:typed_data';

import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:flutter/material.dart';

import '../workspace/file_gateway.dart';
import 'pdf_combine.dart';
import 'pdf_inspection.dart';

/// Allows tests to exercise navigation and validated exports without running
/// the third-party editor. Production uses the real offline editor surface.
typedef PdfEditorBuilder = Widget Function(
  Uint8List bytes, {
  required String documentId,
  required ValueChanged<Uint8List> onSave,
  required ValueChanged<Uint8List> onExportPages,
  required ValueChanged<List<Uint8List>> onSplitPages,
});

/// Existing-PDF reader and editor backed by a cross-platform, offline Dart
/// engine. Saves use a picker; choosing the source path can overwrite it.
class PdfStudioPage extends StatefulWidget {
  const PdfStudioPage({
    super.key,
    required this.picker,
    required this.files,
    this.editorBuilder,
  });

  final DocumentPicker picker;
  final FileGateway files;
  final PdfEditorBuilder? editorBuilder;

  @override
  State<PdfStudioPage> createState() => _PdfStudioPageState();
}

class _PdfStudioPageState extends State<PdfStudioPage> {
  Uint8List? _source;
  String? _sourceName;
  int _documentRevision = 0;
  String? _error;
  String? _status;
  bool _opening = false;
  bool _saving = false;
  bool _combining = false;
  bool _combineMode = false;
  final List<PickedDocument> _combineSources = <PickedDocument>[];
  bool get _busy => _opening || _saving || _combining;

  Future<bool> _confirmLeaving({required bool replacing}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(replacing ? 'Open another PDF?' : 'Close this PDF?'),
        content: const Text(
          'Unsaved changes in this editor will be lost. Save a copy first '
          'if you want to keep them.',
        ),
        actions: [
          TextButton(
            key: const Key('pdf-keep-editing'),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            key: const Key('pdf-discard-changes'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(replacing ? 'Open another' : 'Close PDF'),
          ),
        ],
      ),
    );
    return confirmed == true && mounted;
  }

  Future<void> _open() async {
    if (_busy) return;
    if (_source != null && !await _confirmLeaving(replacing: true)) return;
    if (!mounted || _busy) return;
    setState(() {
      _opening = true;
      _error = null;
      _status = null;
    });
    try {
      final picked = await widget.picker.pickDocument();
      if (picked == null) {
        if (mounted) setState(() => _status = 'No file was chosen.');
        return;
      }
      if (picked.bytes.length > maxPdfBytes) {
        throw const FormatException(
          'This PDF is larger than the 48 MB local editing limit. Use a smaller copy.',
        );
      }
      if (!looksLikePdf(picked.bytes)) {
        throw const FormatException(
          'Choose an existing PDF file. Other document formats belong in Document converter.',
        );
      }
      final report = await inspectPdfInBackground(picked.bytes);
      if (!mounted) return;
      setState(() {
        _source = Uint8List.fromList(picked.bytes);
        _sourceName = pdfBaseName(picked.name);
        _documentRevision++;
        _status =
            'Opened · ${report.pageCount} page(s) · ${report.sizeLabel} · '
            '${report.pageSizeLabel}. Choose a different destination to preserve the original.';
      });
    } on PdfOpenFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not open this PDF: $error');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _close() async {
    if (_busy || _source == null) return;
    if (!await _confirmLeaving(replacing: false) || !mounted || _busy) return;
    setState(() {
      _source = null;
      _sourceName = null;
      _error = null;
      _status = null;
    });
  }

  void _startCombine() {
    setState(() {
      _combineMode = true;
      _combineSources.clear();
      _error = null;
      _status = 'Add at least two PDFs in the order you want them combined.';
    });
  }

  void _cancelCombine() {
    setState(() {
      _combineMode = false;
      _combineSources.clear();
      _error = null;
      _status = null;
    });
  }

  Future<void> _addPdfToCombine() async {
    if (_opening || _saving || _combining) return;
    if (_combineSources.length >= maxPdfCombineDocuments) {
      setState(() => _error = 'Choose no more than 10 PDFs at once.');
      return;
    }
    setState(() {
      _opening = true;
      _error = null;
    });
    try {
      final picked = await widget.picker.pickDocument();
      if (picked == null) return;
      if (!looksLikePdf(picked.bytes)) {
        throw const FormatException(
          'Choose a PDF file, not an image or Office document.',
        );
      }
      final total = _combineSources.fold<int>(
        picked.bytes.length,
        (sum, source) => sum + source.bytes.length,
      );
      if (total > maxPdfCombineBytes) {
        throw const FormatException(
          'The selected PDFs exceed the 48 MB combined limit. Remove a file or choose smaller copies.',
        );
      }
      if (!mounted) return;
      setState(() {
        _combineSources.add((
          bytes: Uint8List.fromList(picked.bytes),
          name: picked.name,
        ));
        _status = '${_combineSources.length} PDF file(s) selected.';
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not add this PDF: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _opening = false);
      }
    }
  }

  void _moveCombineSource(int index, int offset) {
    final destination = index + offset;
    if (destination < 0 || destination >= _combineSources.length) return;
    setState(() {
      final item = _combineSources.removeAt(index);
      _combineSources.insert(destination, item);
    });
  }

  Future<void> _combineAndSave() async {
    if (_combining || _opening || _saving) return;
    if (_combineSources.length < 2) {
      setState(() => _error = 'Add at least two PDF files before combining.');
      return;
    }
    setState(() {
      _combining = true;
      _error = null;
      _status = 'Combining PDFs and checking the output…';
    });
    try {
      final result = await combinePdfsInBackground(
        _combineSources.map((source) => source.bytes).toList(growable: false),
      );
      if (!mounted) return;
      setState(
        () =>
            _status = 'Checking the combined PDF (${result.pageCount} pages)…',
      );
      final saved = await widget.files.save(
        name: combinedPdfName(_combineSources.first.name),
        bytes: result.bytes,
        mimeType: 'application/pdf',
      );
      if (!mounted) return;
      setState(() {
        _status = saved
            ? 'Combined ${result.documentCount} PDFs into ${result.pageCount} pages. Verify the saved copy and choose a separate destination to preserve originals.'
            : 'Export cancelled. No file was written.';
        if (saved) {
          _combineMode = false;
        }
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not combine these PDFs: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _combining = false);
      }
    }
  }

  Future<void> _saveEditedCopy(Uint8List bytes) async {
    final name = _sourceName;
    if (name == null) return;
    await _savePdf(bytes, name: 'edited-$name.pdf', kind: 'Edited copy');
  }

  Future<void> _savePages(Uint8List bytes) async {
    final name = _sourceName;
    if (name == null) return;
    await _savePdf(bytes, name: '$name-pages.pdf', kind: 'Page export');
  }

  Future<void> _savePdf(
    Uint8List bytes, {
    required String name,
    required String kind,
  }) async {
    if (_busy) return;
    setState(() {
      _saving = true;
      _error = null;
      _status = 'Checking $kind…';
    });
    try {
      if (!looksLikePdf(bytes)) {
        throw const PdfOpenFailure(
          'The editor returned bytes that are not a PDF, so nothing was saved.',
        );
      }
      final report = await inspectPdfInBackground(bytes);
      if (!mounted) return;
      final saved = await widget.files.save(
        name: name,
        bytes: bytes,
        mimeType: 'application/pdf',
      );
      if (!mounted) return;
      setState(() {
        _status = saved
            ? '$kind written · ${report.pageCount} page(s) · ${report.sizeLabel}. '
                  'Check the destination and saved file before relying on it.'
            : 'Export cancelled. No file was written.';
      });
    } on PdfOpenFailure catch (failure) {
      if (mounted) {
        setState(() {
          _status = null;
          _error = failure.message;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _status = null;
          _error =
              'Could not export the PDF: $error. Check for an incomplete file.';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveSplit(List<Uint8List> documents) async {
    final name = _sourceName;
    if (_busy || name == null) return;
    if (documents.isEmpty) {
      setState(() {
        _error = null;
        _status = 'No split files were produced.';
      });
      return;
    }
    if (documents.length > 100) {
      setState(() {
        _status = null;
        _error = 'Split into at most 100 files at a time.';
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _status = 'Checking split files…';
    });
    var written = 0;
    var validating = true;
    try {
      // Check the entire set before writing any part. A broken editor result
      // must not produce a partly saved set containing invalid PDFs.
      var totalBytes = 0;
      for (final document in documents) {
        totalBytes += document.length;
        if (totalBytes > maxPdfBytes) {
          throw PdfOpenFailure(
            'The combined split outputs exceed the '
            '${maxPdfBytes ~/ (1024 * 1024)} MiB inspection budget.',
          );
        }
        await inspectPdfInBackground(document);
        if (!mounted) return;
      }
      validating = false;
      if (!mounted) return;
      setState(() => _status = 'Saving split files…');
      for (var i = 0; i < documents.length; i++) {
        final saved = await widget.files.save(
          name: '$name-part-${i + 1}.pdf',
          bytes: documents[i],
          mimeType: 'application/pdf',
        );
        if (!mounted) return;
        if (!saved) {
          setState(() {
            _status =
                'Wrote $written of ${documents.length} file(s); '
                'the remaining exports were cancelled.';
          });
          return;
        }
        written++;
      }
      if (mounted) {
        setState(() {
          _status =
              'Split into ${documents.length} file(s). '
              'Check each saved file before relying on it.';
        });
      }
    } on PdfOpenFailure catch (failure) {
      if (mounted) {
        setState(() {
          _status = null;
          _error = validating
              ? 'Split files could not be verified; no files were written. '
                    '${failure.message}'
              : 'The split stopped after $written confirmed file(s): '
                    '${failure.message}';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _status = null;
          _error = validating
              ? 'Split files could not be verified; no files were written. $error'
              : 'The split stopped after $written confirmed file(s): '
                    '$error. Check the destination for incomplete files.';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildCombineCard(ThemeData theme) => Card(
    key: const Key('pdf-combine-panel'),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Combine PDF files',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add up to 10 PDFs in order. Files are checked before a combined copy is exported. Choose a separate destination to preserve the originals. Total input is limited to 48 MB.',
          ),
          const SizedBox(height: 12),
          if (_combineSources.isEmpty)
            const Text('No PDFs added yet.')
          else
            for (var i = 0; i < _combineSources.length; i++)
              ListTile(
                key: ValueKey('pdf-combine-source-$i'),
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(radius: 15, child: Text('${i + 1}')),
                title: Text(
                  _combineSources[i].name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${(_combineSources[i].bytes.length / 1024).toStringAsFixed(0)} KB',
                ),
                trailing: Wrap(
                  spacing: 0,
                  children: [
                    IconButton(
                      tooltip: 'Move up',
                      onPressed: _combining || _opening || i == 0
                          ? null
                          : () => _moveCombineSource(i, -1),
                      icon: const Icon(Icons.arrow_upward),
                    ),
                    IconButton(
                      tooltip: 'Move down',
                      onPressed:
                          _combining ||
                              _opening ||
                              i == _combineSources.length - 1
                          ? null
                          : () => _moveCombineSource(i, 1),
                      icon: const Icon(Icons.arrow_downward),
                    ),
                    IconButton(
                      tooltip: 'Remove PDF',
                      onPressed: _combining || _opening
                          ? null
                          : () => setState(() => _combineSources.removeAt(i)),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const Key('pdf-combine-add'),
                onPressed: _opening || _combining ? null : _addPdfToCombine,
                icon: const Icon(Icons.add),
                label: Text(_opening ? 'Opening…' : 'Add PDF'),
              ),
              FilledButton.icon(
                key: const Key('pdf-combine-save'),
                onPressed: _combineSources.length < 2 || _opening || _combining
                    ? null
                    : _combineAndSave,
                icon: const Icon(Icons.merge_type),
                label: Text(_combining ? 'Combining…' : 'Combine and export'),
              ),
              TextButton(
                onPressed: _combining ? null : _cancelCombine,
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
      ),
    ),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _sourceName == null ? 'PDF Studio' : 'PDF Studio · $_sourceName',
        ),
        actions: [
          if (_source != null)
            IconButton(
              key: const Key('pdf-studio-open-another'),
              tooltip: 'Open another PDF',
              onPressed: _opening || _saving ? null : _open,
              icon: const Icon(Icons.folder_open_outlined),
            ),
          if (_source != null)
            IconButton(
              key: const Key('pdf-close'),
              tooltip: 'Close this PDF',
              onPressed: _busy ? null : _close,
              icon: const Icon(Icons.close),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_error != null)
            Material(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_error!)),
                    IconButton(
                      tooltip: 'Dismiss error',
                      onPressed: () => setState(() => _error = null),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            ),
          if (_status != null)
            Material(
              color: theme.colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_status!)),
                    if (_saving || _opening || _combining)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: _source == null
                ? ListView(
                    padding: const EdgeInsets.all(22),
                    children: [
                      if (_combineMode) _buildCombineCard(theme),
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
                                'Read, mark up and edit existing PDFs',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Open a PDF stored on this device. The editor supports page management, text and ink annotations, stamps, forms and other PDF edits. Save proposes a copy name. Choose a different destination to preserve the source.',
                              ),
                              const SizedBox(height: 14),
                              FilledButton.icon(
                                key: const Key('pdf-studio-open'),
                                onPressed:
                                    _opening || _combining || _combineMode
                                    ? null
                                    : _open,
                                icon: const Icon(Icons.folder_open_outlined),
                                label: Text(_opening ? 'Opening…' : 'Open PDF'),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                key: const Key('pdf-studio-combine'),
                                onPressed: _opening || _combining
                                    ? null
                                    : _startCombine,
                                icon: const Icon(Icons.library_add_outlined),
                                label: const Text('Combine PDFs'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                          'Privacy: the file is processed locally by the installed engine. Encrypted PDFs are unavailable; damaged or unusually complex files may not open. Keep a verified original backup before editing.',
                        ),
                      ),
                    ],
                  )
                : (widget.editorBuilder ?? _defaultEditor)(
                    _source!,
                    documentId:
                        '${_sourceName ?? 'document'}-$_documentRevision',
                    onSave: _saveEditedCopy,
                    onExportPages: _savePages,
                    onSplitPages: _saveSplit,
                  ),
          ),
        ],
      ),
    );
  }
}
