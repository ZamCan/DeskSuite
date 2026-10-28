import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';

import '../workspace/file_gateway.dart';
import 'office_format.dart';
import 'office_pdf.dart';
import 'office_reader.dart';
import 'office_writer.dart';

enum OfficeEditOutput { pdf, docx, xlsx, odt, ods, txt, csv }

/// A bounded, content-level editor for real office packages.
///
/// It deliberately edits readable paragraphs and table cells, not the
/// original document's complete layout. Export creates a new copy.
class OfficeContentEditorPage extends StatefulWidget {
  const OfficeContentEditorPage({
    super.key,
    required this.source,
    required this.sourceName,
    required this.files,
  });

  final Uint8List source;
  final String sourceName;
  final FileGateway files;

  @override
  State<OfficeContentEditorPage> createState() =>
      _OfficeContentEditorPageState();
}

class _OfficeContentEditorPageState extends State<OfficeContentEditorPage> {
  OfficeDocument? _original;
  OfficeFormat? _format;
  late final TextEditingController _title = TextEditingController();
  List<OfficeBlock> _blocks = [];
  OfficeEditOutput _output = OfficeEditOutput.pdf;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _status;

  bool get _spreadsheet =>
      _format == OfficeFormat.xlsx || _format == OfficeFormat.ods;

  List<OfficeEditOutput> get _availableOutputs => _spreadsheet
      ? const [
          OfficeEditOutput.pdf,
          OfficeEditOutput.xlsx,
          OfficeEditOutput.ods,
          OfficeEditOutput.csv,
          OfficeEditOutput.txt,
        ]
      : const [
          OfficeEditOutput.pdf,
          OfficeEditOutput.docx,
          OfficeEditOutput.odt,
          OfficeEditOutput.txt,
        ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final raw = await compute<Map<String, Object?>, Map<String, Object?>>(
        _readOfficeForEditor,
        <String, Object?>{
          'bytes': widget.source,
          'fileName': widget.sourceName,
        },
      );
      final document = _documentFromMap(raw);
      if (!mounted) return;
      setState(() {
        _original = document;
        _format = document.format;
        _title.text = document.title;
        _blocks = List.of(document.blocks);
        _output = switch (document.format) {
          OfficeFormat.docx => OfficeEditOutput.docx,
          OfficeFormat.xlsx => OfficeEditOutput.xlsx,
          OfficeFormat.ods => OfficeEditOutput.ods,
          _ => OfficeEditOutput.odt,
        };
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            'This document could not be opened for content editing: $error';
      });
    }
  }

  void _addParagraph() {
    setState(() {
      _blocks.add(const OfficeBlock.paragraph(''));
      _status = null;
    });
  }

  void _addTableRow() {
    final existing = _blocks.where(
      (block) => block.kind == OfficeBlockKind.row,
    );
    final width = existing.isEmpty ? 1 : existing.last.cells.length;
    setState(() {
      _blocks.add(OfficeBlock.cells(List<String>.filled(width, '')));
      _status = null;
    });
  }

  void _updateParagraph(int index, String value) {
    final old = _blocks[index];
    setState(() {
      _blocks[index] = OfficeBlock.paragraph(
        value,
        headingLevel: old.headingLevel,
        bold: old.bold,
        italic: old.italic,
      );
      _status = null;
    });
  }

  void _updateCell(int blockIndex, int cellIndex, String value) {
    final old = _blocks[blockIndex];
    final cells = List<String>.of(old.cells);
    cells[cellIndex] = value;
    setState(() {
      _blocks[blockIndex] = OfficeBlock.cells(cells, header: old.header);
      _status = null;
    });
  }

  OfficeDocument _editedDocument() {
    final original = _original!;
    final title = _title.text.trim();
    return OfficeDocument(
      format: original.format,
      title: title.isEmpty ? 'Edited document' : title,
      blocks: List.unmodifiable(_blocks),
      sheetNames: original.sheetNames,
      slideCount: original.slideCount,
      notes: [
        ...original.notes,
        'Edited in DeskSuite content editor. Original page layout, images, '
            'fonts, charts, macros and other unsupported objects are not '
            'preserved by this content-level export.',
      ],
    );
  }

  Future<void> _export() async {
    if (_saving || _original == null) return;
    if (_blocks.isEmpty ||
        _blocks.every(
          (block) =>
              block.kind == OfficeBlockKind.paragraph &&
              block.text.trim().isEmpty,
        )) {
      setState(() => _error = 'Add some readable content before exporting.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _status = 'Preparing a new edited copy…';
    });
    try {
      final document = _editedDocument();
      late final Uint8List bytes;
      late final String extension;
      late final String mime;
      switch (_output) {
        case OfficeEditOutput.pdf:
          bytes = await buildOfficePdf(document);
          extension = 'pdf';
          mime = 'application/pdf';
        case OfficeEditOutput.docx:
          bytes = writeDocx(document);
          extension = 'docx';
          mime = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
        case OfficeEditOutput.xlsx:
          bytes = writeXlsx(document);
          extension = 'xlsx';
          mime = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
        case OfficeEditOutput.odt:
          bytes = writeOdt(document);
          extension = 'odt';
          mime = 'application/vnd.oasis.opendocument.text';
        case OfficeEditOutput.ods:
          bytes = writeOds(document);
          extension = 'ods';
          mime = 'application/vnd.oasis.opendocument.spreadsheet';
        case OfficeEditOutput.txt:
          bytes = Uint8List.fromList(utf8.encode(_plainText(document)));
          extension = 'txt';
          mime = 'text/plain';
        case OfficeEditOutput.csv:
          bytes = Uint8List.fromList(utf8.encode(_csvText(document)));
          extension = 'csv';
          mime = 'text/csv';
      }
      final base = _baseName(widget.sourceName);
      final saved = await widget.files.save(
        name: 'edited-$base.$extension',
        bytes: bytes,
        mimeType: mime,
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _status = saved
            ? 'Exported the edited copy. Choose a different destination to preserve the source.'
            : 'Export cancelled. No file was written.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not export the edited copy: $error';
        _status = null;
      });
    }
  }

  String _plainText(OfficeDocument document) => document.blocks
      .map(
        (block) => switch (block.kind) {
          OfficeBlockKind.paragraph => block.text,
          OfficeBlockKind.row => block.cells.join('\t'),
          OfficeBlockKind.pageBreak => '\n--- page break ---\n',
        },
      )
      .join('\n');

  String _csvText(OfficeDocument document) {
    String cell(String value) {
      if (value.contains(',') ||
          value.contains('"') ||
          value.contains('\n') ||
          value.contains('\r')) {
        return '"${value.replaceAll('"', '""')}"';
      }
      return value;
    }

    return '${document.blocks.where((block) => block.kind == OfficeBlockKind.row).map((block) => block.cells.map(cell).join(',')).join('\r\n')}\r\n';
  }

  String _baseName(String value) {
    final leaf = value.split(RegExp(r'[/\\]')).last;
    final dot = leaf.lastIndexOf('.');
    final withoutExtension = dot > 0 ? leaf.substring(0, dot) : leaf;
    final safe = withoutExtension
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return safe.isEmpty
        ? 'document'
        : safe.substring(0, safe.length > 64 ? 64 : safe.length);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Office content editor')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Office content editor'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              key: const Key('office-editor-export'),
              onPressed: _saving || _original == null ? null : _export,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.file_download_outlined),
              label: Text(_saving ? 'Preparing…' : 'Export copy'),
            ),
          ),
        ],
      ),
      body: _error != null && _original == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CONTENT EDITING',
                          style: theme.textTheme.labelSmall?.copyWith(
                            letterSpacing: 1.2,
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_format!.label} · ${_blocks.length} readable blocks',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Edit the text and table values DeskSuite can read. '
                          'This is not a layout-faithful Word/Excel editor: '
                          'images, page layout, fonts, charts, formulas and '
                          'macros may not survive export. Choose a different save destination to preserve the source.',
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          key: const Key('office-editor-title'),
                          controller: _title,
                          decoration: const InputDecoration(
                            labelText: 'Document title',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<OfficeEditOutput>(
                          key: const Key('office-editor-format'),
                          initialValue: _output,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Export edited copy as',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            for (final value in _availableOutputs)
                              DropdownMenuItem(
                                value: value,
                                child: Text(value.name.toUpperCase()),
                              ),
                          ],
                          onChanged: _saving
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setState(() => _output = value);
                                  }
                                },
                        ),
                      ],
                    ),
                  ),
                ),
                if (_error != null)
                  Card(
                    color: theme.colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(_error!),
                    ),
                  ),
                if (_status != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(_status!),
                    ),
                  ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      key: const Key('office-editor-add-paragraph'),
                      onPressed: _saving ? null : _addParagraph,
                      icon: const Icon(Icons.add),
                      label: const Text('Add paragraph'),
                    ),
                    if (_spreadsheet)
                      OutlinedButton.icon(
                        key: const Key('office-editor-add-row'),
                        onPressed: _saving ? null : _addTableRow,
                        icon: const Icon(Icons.table_rows_outlined),
                        label: const Text('Add table row'),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                for (var index = 0; index < _blocks.length; index++)
                  _blockEditor(index, _blocks[index]),
                const SizedBox(height: 80),
              ],
            ),
    );
  }

  Widget _blockEditor(int index, OfficeBlock block) {
    final theme = Theme.of(context);
    if (block.kind == OfficeBlockKind.pageBreak) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text('PAGE BREAK'),
            ),
            Expanded(child: Divider()),
          ],
        ),
      );
    }
    if (block.kind == OfficeBlockKind.row) {
      return Card(
        key: Key('office-editor-row-$index'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                block.header
                    ? 'Table header / row ${index + 1}'
                    : 'Table row ${index + 1}',
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var cell = 0; cell < block.cells.length; cell++)
                      SizedBox(
                        width: 190,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: TextFormField(
                            key: Key('office-editor-cell-$index-$cell'),
                            initialValue: block.cells[cell],
                            minLines: 1,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: 'Cell ${cell + 1}',
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (value) =>
                                _updateCell(index, cell, value),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Card(
      key: Key('office-editor-block-$index'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: TextFormField(
          key: Key('office-editor-text-$index'),
          initialValue: block.text,
          minLines: block.headingLevel > 0 ? 1 : 2,
          maxLines: block.headingLevel > 0 ? 2 : 6,
          style: block.headingLevel > 0
              ? theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                )
              : theme.textTheme.bodyMedium,
          decoration: InputDecoration(
            labelText: block.headingLevel > 0
                ? 'Heading ${block.headingLevel}'
                : 'Paragraph ${index + 1}',
            border: const OutlineInputBorder(),
          ),
          onChanged: (value) => _updateParagraph(index, value),
        ),
      ),
    );
  }
}

Map<String, Object?> _readOfficeForEditor(Map<String, Object?> request) {
  final bytes = request['bytes']! as Uint8List;
  final fileName = request['fileName'] as String?;
  final document = readOfficeDocument(bytes, fileName: fileName);
  return <String, Object?>{
    'format': document.format.name,
    'title': document.title,
    'blocks': document.blocks.map((block) => block.toJson()).toList(),
    'sheetNames': document.sheetNames,
    'slideCount': document.slideCount,
    'notes': document.notes,
  };
}

OfficeDocument _documentFromMap(Map<String, Object?> value) {
  final blocks = (value['blocks']! as List).map((raw) {
    final row = raw as Map;
    final kind = OfficeBlockKind.values.byName(row['kind']! as String);
    return switch (kind) {
      OfficeBlockKind.paragraph => OfficeBlock.paragraph(
        row['text'] as String? ?? '',
        headingLevel: row['heading'] as int? ?? 0,
        bold: row['bold'] as bool? ?? false,
        italic: row['italic'] as bool? ?? false,
      ),
      OfficeBlockKind.row => OfficeBlock.cells(
        (row['cells']! as List).cast<String>(),
        header: row['header'] as bool? ?? false,
      ),
      OfficeBlockKind.pageBreak => const OfficeBlock.pageBreak(),
    };
  }).toList();
  return OfficeDocument(
    format: OfficeFormat.values.byName(value['format']! as String),
    title: value['title'] as String? ?? 'Document',
    blocks: blocks,
    sheetNames: (value['sheetNames'] as List? ?? const []).cast<String>(),
    slideCount: value['slideCount'] as int? ?? 0,
    notes: (value['notes'] as List? ?? const []).cast<String>(),
  );
}
