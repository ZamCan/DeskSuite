import 'dart:typed_data';

import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:flutter/material.dart';

import '../workspace/file_gateway.dart';
import 'pdf_combine.dart';

/// Existing-PDF reader and editor backed by a cross-platform, offline Dart
/// engine. Edits are saved as a separate copy; the picked source is untouched.
class PdfStudioPage extends StatefulWidget {
  const PdfStudioPage({
    super.key,
    required this.picker,
    required this.files,
  });

  final DocumentPicker picker;
  final FileGateway files;

  @override
  State<PdfStudioPage> createState() => _PdfStudioPageState();
}

class _PdfStudioPageState extends State<PdfStudioPage> {
  // PDF parsers and renderers can expand compressed streams substantially.
  // Bound source and edited-copy bytes before passing them into the editor.
  static const int _maxPdfBytes = 48 * 1024 * 1024;

  Uint8List? _source;
  String? _sourceName;
  String? _error;
  String? _status;
  bool _opening = false;
  bool _saving = false;
  bool _combining = false;
  bool _combineMode = false;
  final List<PickedDocument> _combineSources = <PickedDocument>[];

  Future<void> _open() async {
    if (_opening || _saving || _combining) return;
    setState(() {
      _opening = true;
      _error = null;
      _status = null;
    });
    try {
      final picked = await widget.picker.pickDocument();
      if (picked == null) return;
      if (picked.bytes.length > _maxPdfBytes) {
        throw const FormatException(
          'This PDF is larger than the 48 MB local editing limit. Use a smaller copy.',
        );
      }
      if (!_hasPdfSignature(picked.bytes)) {
        throw const FormatException(
          'Choose an existing PDF file. Other document formats belong in Document converter.',
        );
      }
      if (!mounted) return;
      setState(() {
        _source = Uint8List.fromList(picked.bytes);
        _sourceName = _baseName(picked.name);
        _status = 'Original opened read-only. Save edits as a separate copy.';
      });
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not open this PDF: $error');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
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
      if (!_hasPdfSignature(picked.bytes)) {
        throw const FormatException('Choose a PDF file, not an image or Office document.');
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
      if (mounted) setState(() => _error = 'Could not add this PDF: $error');
    } finally {
      if (mounted) setState(() => _opening = false);
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
      setState(() => _status = 'Checking the combined PDF (${result.pageCount} pages)…');
      final saved = await widget.files.save(
        name: combinedPdfName(_combineSources.first.name),
        bytes: result.bytes,
        mimeType: 'application/pdf',
      );
      if (!mounted) return;
      setState(() {
        _status = saved
            ? 'Combined ${result.documentCount} PDFs into ${result.pageCount} pages. The originals were not changed.'
            : 'Export cancelled. No file was written.';
        if (saved) {
          _combineMode = false;
        }
      });
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not combine these PDFs: $error');
    } finally {
      if (mounted) {
        setState(() => _combining = false);
      }
    }
  }

  Future<void> _saveEditedCopy(Uint8List bytes) async {
    if (_saving || _combining || _sourceName == null) return;
    setState(() {
      _saving = true;
      _error = null;
      _status = 'Saving a separate PDF copy…';
    });
    try {
      if (bytes.length > _maxPdfBytes) {
        throw const FormatException(
          'The edited PDF exceeds the 48 MB export limit. Reduce its size and try again.',
        );
      }
      if (!_hasPdfSignature(bytes)) {
        throw const FormatException('The PDF editor returned invalid PDF bytes.');
      }
      final saved = await widget.files.save(
        name: 'edited-${_sourceName!}.pdf',
        bytes: bytes,
        mimeType: 'application/pdf',
      );
      if (!mounted) return;
      setState(() {
        _status = saved
            ? 'Edited PDF exported. The original file was not changed.'
            : 'Export cancelled. No file was written.';
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not export the edited PDF: $error');
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
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add up to 10 PDFs in order. Files are checked before a new combined copy is exported; originals are not modified. Total input is limited to 48 MB.',
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
                title: Text(_combineSources[i].name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('${(_combineSources[i].bytes.length / 1024).toStringAsFixed(0)} KB'),
                trailing: Wrap(
                  spacing: 0,
                  children: [
                    IconButton(
                      tooltip: 'Move up',
                      onPressed: _combining || _opening || i == 0 ? null : () => _moveCombineSource(i, -1),
                      icon: const Icon(Icons.arrow_upward),
                    ),
                    IconButton(
                      tooltip: 'Move down',
                      onPressed: _combining || _opening || i == _combineSources.length - 1 ? null : () => _moveCombineSource(i, 1),
                      icon: const Icon(Icons.arrow_downward),
                    ),
                    IconButton(
                      tooltip: 'Remove PDF',
                      onPressed: _combining || _opening ? null : () => setState(() => _combineSources.removeAt(i)),
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
                onPressed: _combineSources.length < 2 || _opening || _combining ? null : _combineAndSave,
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

  bool _hasPdfSignature(Uint8List bytes) {
    // PDF producers may place a short preamble before the header; the format
    // permits the signature within the first 1024 bytes.
    if (bytes.length < 5) return false;
    final lastOffset = bytes.length < 1029 ? bytes.length - 5 : 1024;
    for (var offset = 0; offset <= lastOffset; offset++) {
      if (bytes[offset] == 0x25 &&
          bytes[offset + 1] == 0x50 &&
          bytes[offset + 2] == 0x44 &&
          bytes[offset + 3] == 0x46 &&
          bytes[offset + 4] == 0x2d) {
        return true;
      }
    }
    return false;
  }

  String _baseName(String name) {
    final leaf = name.split(RegExp(r'[/\\]')).last;
    final dot = leaf.lastIndexOf('.');
    final value = dot > 0 ? leaf.substring(0, dot) : leaf;
    final safe = value
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return safe.isEmpty ? 'document' : safe.substring(0, safe.length > 64 ? 64 : safe.length);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_sourceName == null ? 'PDF Studio' : 'PDF Studio · $_sourceName'),
        actions: [
          if (_source != null)
            IconButton(
              key: const Key('pdf-studio-open-another'),
              tooltip: 'Open another PDF',
              onPressed: _opening || _saving ? null : _open,
              icon: const Icon(Icons.folder_open_outlined),
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                                'Open a PDF stored on this device. The editor supports page management, text and ink annotations, stamps, forms and other PDF edits. Save creates a separate copy; it does not overwrite the source automatically.',
                              ),
                              const SizedBox(height: 14),
                              FilledButton.icon(
                                key: const Key('pdf-studio-open'),
                                onPressed: _opening || _combining || _combineMode ? null : _open,
                                icon: const Icon(Icons.folder_open_outlined),
                                label: Text(_opening ? 'Opening…' : 'Open PDF'),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                key: const Key('pdf-studio-combine'),
                                onPressed: _opening || _combining ? null : _startCombine,
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
                          'Privacy: the file is processed locally by the installed engine. Protected, damaged or unusually complex PDFs may not open; keep a verified original backup before editing.',
                        ),
                      ),
                    ],
                  )
                : PdfEditorView(
                    key: ValueKey('pdf-editor-$_sourceName'),
                    bytes: _source!,
                    onSave: _saveEditedCopy,
                  ),
          ),
        ],
      ),
    );
  }
}
