import 'dart:typed_data';

import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:flutter/material.dart';

import '../workspace/file_gateway.dart';

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
  Uint8List? _source;
  String? _sourceName;
  String? _error;
  String? _status;
  bool _opening = false;
  bool _saving = false;

  Future<void> _open() async {
    if (_opening || _saving) return;
    setState(() {
      _opening = true;
      _error = null;
      _status = null;
    });
    try {
      final picked = await widget.picker.pickDocument();
      if (picked == null) return;
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

  Future<void> _saveEditedCopy(Uint8List bytes) async {
    if (_saving || _sourceName == null) return;
    setState(() {
      _saving = true;
      _error = null;
      _status = 'Saving a separate PDF copy…';
    });
    try {
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
    final leaf = name.split(RegExp(r'[/\\\\]')).last;
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
                    if (_saving || _opening)
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
                                onPressed: _opening ? null : _open,
                                icon: const Icon(Icons.folder_open_outlined),
                                label: Text(_opening ? 'Opening…' : 'Open PDF'),
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
