import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';

import '../printing/paper_catalog.dart';
import '../workspace/file_gateway.dart';
import 'office_content_editor_page.dart';
import 'office_engine.dart';
import 'office_format.dart';
import 'office_preview_page.dart';
import 'office_template_catalog.dart';

/// Convert a supported document with a real engine, showing the detected
/// format, only the routes that can actually run, the fidelity of each route
/// and the final output size.
class OfficeConvertPage extends StatefulWidget {
  const OfficeConvertPage({
    super.key,
    required this.picker,
    required this.files,
    this.engine,
    this.pickDocument,
  });

  final DocumentPicker picker;
  final FileGateway files;

  /// Injected in tests so an external office engine can be simulated.
  final OfficeEngine? engine;

  /// Injected in tests to supply document bytes without a platform picker.
  final Future<({Uint8List bytes, String name})?> Function()? pickDocument;

  @override
  State<OfficeConvertPage> createState() => _OfficeConvertPageState();
}

class _OfficeConvertPageState extends State<OfficeConvertPage> {
  late final OfficeEngine _engine = widget.engine ?? OfficeEngine();
  Uint8List? _source;
  String? _sourceName;
  OfficeTemplateDefinition? _template;
  DetectedFile? _detected;
  List<OfficeRoute> _routes = const [];
  OfficeRoute? _selected;
  OfficeConversion? _output;
  String? _error;
  String? _status;
  bool _busy = false;
  int _pdfPresetIndex = 0;
  final _pdfWidth = TextEditingController(text: '210');
  final _pdfHeight = TextEditingController(text: '297');

  @override
  void dispose() {
    _pdfWidth.dispose();
    _pdfHeight.dispose();
    super.dispose();
  }

  void _selectPdfPreset(int? index) {
    if (index == null) return;
    setState(() {
      _pdfPresetIndex = index;
      if (index < paperSheetPresets.length) {
        _pdfWidth.text = paperSheetPresets[index].widthMm.toString();
        _pdfHeight.text = paperSheetPresets[index].heightMm.toString();
      }
    });
  }

  Future<void> _pick() async {
    if (_busy) return;
    setState(() => _error = null);
    try {
      final picked = widget.pickDocument == null
          ? await _pickFromStore()
          : await widget.pickDocument!();
      if (picked == null || !mounted) return;
      await _load(picked.bytes, picked.name);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not open this file: $error');
      }
    }
  }

  Future<({Uint8List bytes, String name})?> _pickFromStore() =>
      widget.picker.pickDocument();


  Future<void> _load(
    Uint8List bytes,
    String name, {
    OfficeTemplateDefinition? template,
  }) async {
    setState(() {
      _busy = true;
      _output = null;
      _status = null;
      _selected = null;
      _routes = const [];
      _detected = null;
      _error = null;
      _source = bytes;
      _sourceName = name;
      _template = template;
    });
    try {
      final detected = await detectOfficeFileInBackground(
        bytes,
        fileName: name,
      );
      final expected = switch (template?.kind) {
        OfficeTemplateKind.word => OfficeFormat.docx,
        OfficeTemplateKind.spreadsheet => OfficeFormat.xlsx,
        OfficeTemplateKind.presentation => OfficeFormat.pptx,
        null => null,
      };
      if (expected != null && detected.format != expected) {
        throw const FormatException(
          'The bundled template has an unexpected format.',
        );
      }
      final routes = await _engine.routesFor(detected.format);
      if (!mounted) return;
      setState(() {
        _detected = detected;
        _routes = routes;
        _selected = routes.isEmpty ? null : routes.first;
        _busy = false;
        _status = routes.isEmpty
            ? 'No conversion is available for this format in this build.'
            : null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$error';
      });
    }
  }

  Future<void> _saveOriginalTemplate() async {
    final template = _template;
    final source = _source;
    if (_busy || template == null || source == null || _detected == null) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _status = null;
    });
    try {
      final saved = await widget.files.save(
        name: 'copy-${template.fileName}',
        bytes: source,
        mimeType: template.mimeType,
      );
      if (!mounted) return;
      setState(
        () => _status = saved
            ? 'Saved an unchanged copy of the bundled template.'
            : 'Save cancelled. Nothing was written.',
      );
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not save the template: $error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _convert() async {
    final source = _source;
    final route = _selected;
    if (source == null || route == null || _busy) return;
    PdfPageFormat pdfPageFormat = PdfPageFormat.a4;
    if (route.to == OfficeFormat.pdf && !route.requiresExternalEngine) {
      final width = double.tryParse(_pdfWidth.text);
      final height = double.tryParse(_pdfHeight.text);
      if (width == null ||
          height == null ||
          !validPdfPageDimensions(width, height)) {
        setState(
          () => _error = 'Enter both PDF page dimensions from 20 to 2500 mm.',
        );
        return;
      }
      pdfPageFormat = PdfPageFormat(
        width * PdfPageFormat.mm,
        height * PdfPageFormat.mm,
      );
    }
    setState(() {
      _busy = true;
      _error = null;
      _status = 'Converting with ${route.engine}…';
    });
    try {
      final conversion = await _engine.convert(
        bytes: source,
        route: route,
        sourceName: _sourceName,
        pdfPageFormat: pdfPageFormat,
      );
      if (!mounted) return;
      setState(() {
        _output = conversion;
        _busy = false;
        _status = 'Converted to ${conversion.format.label}.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = null;
        _error = 'Conversion failed: $error';
      });
    }
  }

  Future<void> _save() async {
    final output = _output;
    if (output == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await widget.files.save(
        name: output.fileName,
        bytes: output.bytes,
        mimeType: _mimeFor(output.format),
      );
      if (!mounted) return;
      setState(
        () => _status = saved
            ? 'Saved the converted output. Choose a different destination to preserve the source.'
            : 'Save cancelled. Nothing was written.',
      );
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not save: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _mimeFor(OfficeFormat format) => switch (format) {
    OfficeFormat.pdf => 'application/pdf',
    OfficeFormat.odt => 'application/vnd.oasis.opendocument.text',
    OfficeFormat.ods => 'application/vnd.oasis.opendocument.spreadsheet',
    OfficeFormat.docx =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    OfficeFormat.xlsx =>
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    _ => 'text/plain',
  };

  static String _size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        Text(
          'Convert documents',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Reads DOCX, XLSX, PPTX, ODT, ODS, ODP, RTF and text files on this '
          'device. Only conversion routes that can really run are offered, and '
          'choose a different save destination to preserve the original.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '1. Choose a document',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      key: const Key('office-choose'),
                      onPressed: _busy ? null : _pick,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Choose file'),
                    ),
                  ],
                ),
                if (_detected != null) ...[
                  const SizedBox(height: 14),
                  _InfoRow(
                    label: 'Detected',
                    value:
                        '${_detected!.format.label} — ${_detected!.format.description}',
                  ),
                  _InfoRow(label: 'Detected by', value: _detected!.detail),
                  _InfoRow(
                    label: 'Source size',
                    value: _source == null ? '—' : _size(_source!.length),
                  ),
                  _InfoRow(
                    label: 'Protect source',
                    value: 'Choose a different save destination to avoid overwriting an existing file.',
                  ),
                  if (_template != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Selected template: ${_template!.title}',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _template!.kind == OfficeTemplateKind.presentation
                          ? 'Save the original slides for editing in a compatible presentation app. DeskSuite cannot export edited PPTX layouts.'
                          : _template!.kind == OfficeTemplateKind.spreadsheet
                          ? 'The unchanged workbook includes formulas and styles. DeskSuite content exports flatten formulas and formatting.'
                          : 'The unchanged DOCX keeps its layout. DeskSuite content exports are simplified.',
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      key: const Key('office-save-template'),
                      onPressed: _busy ? null : _saveOriginalTemplate,
                      icon: const Icon(Icons.save_alt),
                      label: const Text('Save unchanged template'),
                    ),
                  ],
                  if (canPreviewOfficeFormat(_detected!.format)) ...[
                    const SizedBox(height: 12),
                    if (officePreviewEnabled &&
                        officePreviewPlatformSupported) ...[
                      OutlinedButton.icon(
                        key: const Key('office-preview-original'),
                        onPressed:
                            _busy ||
                                _source == null ||
                                _sourceName == null ||
                                _source!.length > officePreviewMaxBytes
                            ? null
                            : () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => OfficePreviewPage(
                                    source: _source!,
                                    sourceName: _sourceName!,
                                  ),
                                ),
                              ),
                        icon: const Icon(Icons.visibility_outlined),
                        label: const Text(
                          'Preview original layout (experimental)',
                        ),
                      ),
                      if (_source != null &&
                          _source!.length > officePreviewMaxBytes)
                        const Text(
                          'Experimental preview supports files up to 8 MB.',
                        ),
                    ] else if (_detected!.format.isLegacyBinary)
                      const Text(
                        'Legacy DOC, XLS and PPT conversion is unavailable. '
                        'The original-layout preview is still being validated '
                        'and is disabled in this build.',
                      )
                    else if (_detected!.format == OfficeFormat.ole)
                      const Text(
                        'This compound file could be a legacy or encrypted '
                        'Office document; its exact type is unconfirmed. '
                        'Preview and conversion are unavailable in this build.',
                      ),
                  ],
                  if (_detected!.format.isReadable) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      key: const Key('office-open-content-editor'),
                      onPressed: _busy || _source == null || _sourceName == null
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => OfficeContentEditorPage(
                                  source: _source!,
                                  sourceName: _sourceName!,
                                  files: widget.files,
                                ),
                              ),
                            ),
                      icon: const Icon(Icons.edit_note_outlined),
                      label: const Text('Edit readable content'),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Card(
            color: theme.colorScheme.errorContainer,
            child: ListTile(
              leading: const Icon(Icons.error_outline),
              title: Text(_error!),
              trailing: IconButton(
                tooltip: 'Dismiss',
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _error = null),
              ),
            ),
          ),
        ],
        if (_status != null) ...[
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(_status!),
            ),
          ),
        ],
        if (_routes.isNotEmpty) ...[
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '2. Choose an output',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final route in _routes)
                    RadioListTile<OfficeRoute>(
                      key: Key('office-route-${route.id}'),
                      value: route,
                      // ignore: deprecated_member_use
                      groupValue: _selected,
                      // ignore: deprecated_member_use
                      onChanged: _busy
                          ? null
                          : (value) => setState(() => _selected = value),
                      contentPadding: EdgeInsets.zero,
                      title: Text('${route.from.label} → ${route.to.label}'),
                      subtitle: Text(
                        '${route.fidelity.description}. ${route.detail}'
                        '${route.requiresExternalEngine ? ' (external engine)' : ''}',
                      ),
                    ),
                  if (_selected != null && _selected!.notes.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    for (final note in _selected!.notes)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• '),
                            Expanded(
                              child: Text(
                                note,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  if (_selected?.to == OfficeFormat.pdf &&
                      !(_selected?.requiresExternalEngine ?? false)) ...[
                    const Divider(height: 24),
                    DropdownButtonFormField<int>(
                      key: const Key('office-pdf-paper-preset'),
                      initialValue: _pdfPresetIndex,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'PDF physical page size',
                      ),
                      items: [
                        for (var i = 0; i < paperSheetPresets.length; i++)
                          DropdownMenuItem(
                            value: i,
                            child: Text(
                              paperSheetPresets[i].label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        DropdownMenuItem(
                          value: paperSheetPresets.length,
                          child: const Text('Custom dimensions'),
                        ),
                      ],
                      onChanged: _busy ? null : _selectPdfPreset,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const Key('office-pdf-width'),
                            controller: _pdfWidth,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Width (mm)',
                            ),
                            onChanged: (_) {
                              if (_pdfPresetIndex != paperSheetPresets.length) {
                                setState(
                                  () => _pdfPresetIndex =
                                      paperSheetPresets.length,
                                );
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            key: const Key('office-pdf-height'),
                            controller: _pdfHeight,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Height (mm)',
                            ),
                            onChanged: (_) {
                              if (_pdfPresetIndex != paperSheetPresets.length) {
                                setState(
                                  () => _pdfPresetIndex =
                                      paperSheetPresets.length,
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const Text(
                      'This changes the generated PDF page geometry, not the source document layout. External Office rendering uses its own page setup.',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                  ],
                  FilledButton.icon(
                    key: const Key('office-convert'),
                    onPressed: _busy || _selected == null ? null : _convert,
                    icon: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.swap_horiz),
                    label: Text(_busy ? 'Working…' : 'Convert'),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (_output != null) ...[
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '3. Review and save',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _InfoRow(label: 'Output', value: _output!.fileName),
                  _InfoRow(label: 'Format', value: _output!.format.label),
                  _InfoRow(
                    label: 'Output size',
                    value: _size(_output!.sizeBytes),
                  ),
                  _InfoRow(label: 'Engine', value: _output!.route.engine),
                  if (_output!.notes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'What changed',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    for (final note in _output!.notes)
                      Text(
                        '• $note',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        key: const Key('office-save'),
                        onPressed: _busy ? null : _save,
                        icon: const Icon(Icons.save_alt),
                        label: const Text('Save output'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}
