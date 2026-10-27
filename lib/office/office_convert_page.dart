import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../workspace/file_gateway.dart';
import 'office_engine.dart';
import 'office_format.dart';

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
    this.sampleLoader,
  });

  final DocumentPicker picker;
  final FileGateway files;

  /// Injected in tests so an external office engine can be simulated.
  final OfficeEngine? engine;

  /// Injected in tests to supply document bytes without a platform picker.
  final Future<({Uint8List bytes, String name})?> Function()? pickDocument;

  /// Injected in tests to avoid the asset bundle.
  final Future<({Uint8List bytes, String name})?> Function()? sampleLoader;

  @override
  State<OfficeConvertPage> createState() => _OfficeConvertPageState();
}

class _OfficeConvertPageState extends State<OfficeConvertPage> {
  late final OfficeEngine _engine = widget.engine ?? OfficeEngine();
  Uint8List? _source;
  String? _sourceName;
  DetectedFile? _detected;
  List<OfficeRoute> _routes = const [];
  OfficeRoute? _selected;
  OfficeConversion? _output;
  String? _error;
  String? _status;
  bool _busy = false;

  Future<void> _pick() async {
    if (_busy) return;
    setState(() => _error = null);
    try {
      final picked = widget.pickDocument == null
          ? await _pickFromStore()
          : await widget.pickDocument!();
      if (picked == null) return;
      await _load(picked.bytes, picked.name);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not open this file: $error');
      }
    }
  }

  Future<({Uint8List bytes, String name})?> _pickFromStore() =>
      widget.picker.pickDocument();

  Future<void> _loadSample() async {
    if (_busy) return;
    setState(() => _error = null);
    final loader = widget.sampleLoader;
    if (loader == null) {
      setState(
        () => _error =
            'No sample document is bundled in this build. Choose a file '
            'instead.',
      );
      return;
    }
    try {
      final sample = await loader();
      if (sample == null) return;
      await _load(sample.bytes, sample.name);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'The sample could not be loaded: $error');
      }
    }
  }

  Future<void> _load(Uint8List bytes, String name) async {
    setState(() {
      _busy = true;
      _output = null;
      _status = null;
      _selected = null;
      _routes = const [];
      _detected = null;
      _source = bytes;
      _sourceName = name;
    });
    try {
      final detected = detectOfficeFile(bytes, fileName: name);
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

  Future<void> _convert() async {
    final source = _source;
    final route = _selected;
    if (source == null || route == null || _busy) return;
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
    if (output == null) return;
    try {
      final saved = await widget.files.save(
        name: output.fileName,
        bytes: output.bytes,
        mimeType: _mimeFor(output.format),
      );
      if (!mounted) return;
      setState(
        () => _status = saved
            ? 'Saved ${output.fileName}. Your original file was not changed.'
            : 'Save cancelled. Nothing was written.',
      );
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not save: $error');
    }
  }

  static String _mimeFor(OfficeFormat format) => switch (format) {
    OfficeFormat.pdf => 'application/pdf',
    OfficeFormat.odt => 'application/vnd.oasis.opendocument.text',
    OfficeFormat.ods => 'application/vnd.oasis.opendocument.spreadsheet',
    OfficeFormat.docx =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
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
          'the original file is never modified.',
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
                    OutlinedButton.icon(
                      key: const Key('office-sample'),
                      onPressed: _busy ? null : _loadSample,
                      icon: const Icon(Icons.school_outlined),
                      label: const Text('Use sample document'),
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
                    label: 'Source preserved',
                    value: 'Yes — output is written to a new file you choose.',
                  ),
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
                  const SizedBox(height: 12),
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
                        onPressed: _save,
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
