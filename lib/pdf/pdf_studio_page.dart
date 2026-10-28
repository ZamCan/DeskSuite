import 'dart:typed_data';

import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:flutter/material.dart';

import '../workspace/file_gateway.dart';
import 'pdf_inspection.dart';

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
/// The picked bytes are read without modification. Exports suggest new names;
/// the user must choose a different destination to preserve the original file.
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
            'Choose a different destination to preserve the original.';
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
                  'Check the saved file before relying on it.'
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
              'The PDF could not be written: $error. '
              'Check the destination for an incomplete file.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _close() async {
    if (_busy || _source == null) return;
    if (!await _confirmLeaving(replacing: false) || !mounted || _busy) return;
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
      _busy = true;
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
        inspectPdf(document);
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
          _error =
              'The split stopped after $written confirmed file(s): '
              '$error. Check the destination for incomplete files.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
                'pages. Exports suggest new names; choose a separate '
                'destination to preserve the file you opened.',
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                key: const Key('pdf-open'),
                onPressed: _busy ? null : _open,
                icon: const Icon(Icons.folder_open_outlined),
                label: Text(_busy ? 'Opening…' : 'Open PDF'),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          'Processed on this device; nothing is uploaded. The document picker '
          'accepts files up to ${maxPickedDocumentBytes ~/ (1024 * 1024)} MiB. '
          'Encrypted PDFs are not supported, and damaged or complex files may '
          'look different from another reader.',
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

/// A file name derived from the picked name: no directories, no traversal, no
/// characters that break Android's file names, and never empty.
String pdfBaseName(String name) {
  final leaf = name.split(RegExp(r"[/\\]")).last;
  final dot = leaf.lastIndexOf('.');
  final value = dot > 0 ? leaf.substring(0, dot) : leaf;
  final safe = value
      // Anything that is not a letter, digit, space, underscore or hyphen
      // becomes a hyphen, so a name can never escape the export directory.
      .replaceAll(RegExp(r'[^A-Za-z0-9 _-]+'), '-')
      .trim()
      // Collapse runs of separators so "a  b--c" does not become "a--b--c".
      .replaceAll(RegExp(r'[\s_-]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  if (safe.isEmpty) return 'document';
  return safe.length > 60 ? safe.substring(0, 60) : safe;
}
