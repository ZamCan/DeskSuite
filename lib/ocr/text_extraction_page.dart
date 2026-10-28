import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../workspace/file_gateway.dart';
import 'ocr_engine.dart';
import 'ocr_image_prep.dart';
import 'searchable_pdf.dart';
import 'text_exports.dart';

/// Extract text from a photo or image with the on-device recognizer, then let
/// the user review, correct and export it.
///
/// The screen never claims recognition happened unless an engine returned a
/// result; unavailable/failed states are shown explicitly.
class TextExtractionPage extends StatefulWidget {
  const TextExtractionPage({
    super.key,
    required this.files,
    this.engine,
    this.sampleLoader,
    this.prepare,
    this.initialImage,
  });

  final FileGateway files;

  /// Injected in tests; defaults to the Android Tesseract engine.
  final OcrEngine? engine;

  /// Injected in tests to avoid depending on the asset bundle.
  final Future<Uint8List?> Function()? sampleLoader;

  /// Injected in tests so the widget does not need an isolate; production uses
  /// [prepareImageForOcrInBackground].
  final Future<Uint8List> Function(Uint8List bytes)? prepare;

  /// Optional selected scan page. Recognition remains an explicit user action.
  final Uint8List? initialImage;

  @override
  State<TextExtractionPage> createState() => _TextExtractionPageState();
}

class _TextExtractionPageState extends State<TextExtractionPage> {
  late final OcrEngine _engine = widget.engine ?? TesseractOcrEngine();
  final TextEditingController _text = TextEditingController();

  bool? _available;
  String? _availabilityError;
  String _language = 'eng';
  Uint8List? _prepared;
  Uint8List? _original;
  OcrResult? _result;
  String? _error;
  String? _status;
  bool _running = false, _preparing = false;
  int _loadGeneration = 0;
  String? _sourceLabel;

  @override
  void initState() {
    super.initState();
    _checkAvailability();
    final image = widget.initialImage;
    if (image != null) {
      _preparing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load(image, 'Selected scan page');
      });
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _checkAvailability() async {
    try {
      final available = await _engine.isAvailable();
      if (!mounted) return;
      setState(() => _available = available);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _available = false;
        _availabilityError = '$error';
      });
    }
  }

  Future<void> _load(Uint8List? bytes, String label) async {
    if (bytes == null) return;
    final generation = ++_loadGeneration;
    setState(() {
      _preparing = true;
      _error = null;
      _status = 'Preparing image…';
      _original = null;
      _prepared = null;
      _result = null;
      _text.clear();
      _sourceLabel = label;
    });
    try {
      final prepared =
          await (widget.prepare ??
              (bytes) => prepareImageForOcrInBackground(
                OcrImageRequest(bytes),
              ))(bytes);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _original = bytes;
        _prepared = prepared;
        _status = null;
        _preparing = false;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _error = 'This image could not be prepared: $error';
        _status = null;
        _preparing = false;
      });
    }
  }

  Future<void> _pick() async {
    if (_running || _preparing) return;
    setState(() => _preparing = true);
    try {
      final bytes = await widget.files.pickImage();
      if (mounted) await _load(bytes, 'Imported image');
    } catch (error) {
      if (mounted) setState(() => _error = 'Import failed: $error');
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }

  Future<void> _loadSample() async {
    if (_running || _preparing) return;
    setState(() => _preparing = true);
    try {
      final loader =
          widget.sampleLoader ??
          () async {
            final data = await rootBundle.load('assets/samples/letter.png');
            return data.buffer.asUint8List();
          };
      final bytes = await loader();
      if (mounted) await _load(bytes, 'Sample letter (example document)');
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Sample could not be loaded: $error');
      }
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }

  Future<void> _recognize() async {
    final prepared = _prepared;
    if (prepared == null || _running || _preparing) return;
    setState(() {
      _running = true;
      _error = null;
      _status = 'Recognizing text on this device…';
    });
    try {
      final result = await _engine.recognize(
        imageBytes: prepared,
        language: _language,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _text.text = normalizeOcrText(result.text);
        _running = false;
        _status = null;
      });
    } on OcrUnavailable catch (error) {
      if (!mounted) return;
      setState(() {
        _running = false;
        _status = null;
        _error = error.message;
      });
    } on OcrFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _running = false;
        _status = null;
        _error = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _running = false;
        _status = null;
        _error = 'Recognition failed: $error';
      });
    }
  }

  Future<void> _save({
    required String name,
    required Uint8List bytes,
    required String mime,
  }) async {
    try {
      final saved = await widget.files.save(
        name: name,
        bytes: bytes,
        mimeType: mime,
      );
      if (!mounted) return;
      setState(
        () => _status = saved
            ? 'Saved $name to the destination you chose.'
            : 'Save cancelled. Nothing was written.',
      );
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not save $name: $error');
    }
  }

  Future<void> _exportText() async {
    final text = _text.text;
    if (text.trim().isEmpty) {
      setState(() => _error = 'There is no reviewed text to export yet.');
      return;
    }
    await _save(
      name: 'desksuite-extracted-text.txt',
      bytes: buildPlainText(text),
      mime: 'text/plain',
    );
  }

  Future<void> _exportDocx() async {
    final text = _text.text;
    if (text.trim().isEmpty) {
      setState(() => _error = 'There is no reviewed text to export yet.');
      return;
    }
    await _save(
      name: 'desksuite-extracted-text.docx',
      bytes: buildDocx(text, title: 'DeskSuite extracted text'),
      mime: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    );
  }

  Future<void> _exportSearchablePdf() async {
    final prepared = _prepared;
    final result = _result;
    if (prepared == null || result == null) {
      setState(() => _error = 'Recognize text before building a PDF.');
      return;
    }
    if (result.words.isEmpty) {
      setState(
        () => _error =
            'No word positions were returned, so a searchable layer cannot be '
            'built. Export the reviewed text instead.',
      );
      return;
    }
    if (normalizeOcrText(_text.text) != normalizeOcrText(result.text)) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('PDF layer uses original OCR'),
          content: const Text(
            'Your text edits are saved in TXT or DOCX, but the PDF search layer '
            'uses the original recognized words and positions. It will not '
            'include your corrections. Continue with the original OCR layer?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('ocr-confirm-original-layer'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Use original OCR layer'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
    }
    try {
      final bytes = await buildSearchablePdf([
        SearchablePage(imageBytes: prepared, result: result),
      ], title: 'DeskSuite searchable scan');
      await _save(
        name: 'desksuite-searchable.pdf',
        bytes: bytes,
        mime: 'application/pdf',
      );
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not build the searchable PDF: $error');
      }
    }
  }

  Future<void> _copy() async {
    if (_text.text.trim().isEmpty) {
      setState(() => _error = 'There is no reviewed text to copy yet.');
      return;
    }
    await Clipboard.setData(ClipboardData(text: _text.text));
    if (mounted) setState(() => _status = 'Text copied to the clipboard.');
  }

  void _reset() {
    _loadGeneration++;
    setState(() {
      _preparing = false;
      _original = null;
      _prepared = null;
      _result = null;
      _text.clear();
      _error = null;
      _status = null;
      _sourceLabel = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        Text(
          'Extract text',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -.4),
        ),
        const SizedBox(height: 6),
        Text(
          'Offline recognition of a photo or image you choose. Review the text '
          'before you rely on it; complex tables, columns and handwriting are '
          'not reconstructed.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 18),
        _availabilityCard(),
        if (_error != null) ...[const SizedBox(height: 12), _errorCard()],
        if (_status != null) ...[const SizedBox(height: 12), _statusCard()],
        const SizedBox(height: 18),
        _sourceCard(),
        const SizedBox(height: 18),
        if (_result != null) _resultCard(),
      ],
    );
  }

  Widget _availabilityCard() {
    final scheme = Theme.of(context).colorScheme;
    if (_available == null) {
      return const Card(
        child: ListTile(
          leading: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          title: Text('Checking the offline recognizer…'),
        ),
      );
    }
    if (_available == true) {
      return Card(
        child: ListTile(
          leading: Icon(Icons.verified_outlined, color: scheme.primary),
          title: const Text('Offline recognizer ready'),
          subtitle: Text(
            '${_engine.label}. Images stay on this device. Languages: '
            'English and English + Kiswahili.',
          ),
        ),
      );
    }
    return Card(
      color: scheme.errorContainer,
      child: ListTile(
        leading: Icon(Icons.report_gmailerrorred_outlined, color: scheme.error),
        title: const Text('Recognition is not available on this build'),
        subtitle: Text(
          _availabilityError ??
              'The recognizer or its language model is missing. Text '
                  'extraction needs the Android app with bundled OCR models.',
        ),
      ),
    );
  }

  Widget _errorCard() => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: ListTile(
      leading: const Icon(Icons.error_outline),
      title: Text(_error!),
      trailing: IconButton(
        tooltip: 'Dismiss',
        icon: const Icon(Icons.close),
        onPressed: () => setState(() => _error = null),
      ),
    ),
  );

  Widget _statusCard() => Card(
    child: ListTile(
      leading: const Icon(Icons.info_outline),
      title: Text(_status!),
    ),
  );

  Widget _sourceCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '1. Choose an image',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                key: const Key('ocr-choose'),
                onPressed: _running || _preparing ? null : _pick,
                icon: const Icon(Icons.upload_file),
                label: const Text('Choose image'),
              ),
              OutlinedButton.icon(
                key: const Key('ocr-sample'),
                onPressed: _running || _preparing ? null : _loadSample,
                icon: const Icon(Icons.school_outlined),
                label: const Text('Use sample letter'),
              ),
              if (_prepared != null)
                TextButton.icon(
                  key: const Key('ocr-reset'),
                  onPressed: _running || _preparing ? null : _reset,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Start over'),
                ),
            ],
          ),
          if (_prepared != null) ...[
            const SizedBox(height: 14),
            if (_original != null)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    _original!,
                    key: const Key('ocr-preview'),
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              _sourceLabel ?? 'Selected image',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 18),
          Text(
            '2. Recognize',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DropdownButton<String>(
                key: const Key('ocr-language'),
                // The "English + Kiswahili" label is wider than a phone-width
                // Wrap line, and without this the button's inner Row overflows
                // on a 320 px screen.
                isExpanded: true,
                value: _language,
                onChanged: _running || _preparing
                    ? null
                    : (value) => setState(() => _language = value ?? 'eng'),
                items: const [
                  DropdownMenuItem(value: 'eng', child: Text('English')),
                  DropdownMenuItem(
                    value: 'eng+swa',
                    child: Text('English + Kiswahili'),
                  ),
                ],
              ),
              FilledButton.icon(
                key: const Key('ocr-run'),
                onPressed:
                    (_prepared == null ||
                        _running ||
                        _preparing ||
                        _available != true)
                    ? null
                    : _recognize,
                icon: _running
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.text_fields),
                label: Text(_running ? 'Recognizing…' : 'Extract text'),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _resultCard() {
    final result = _result!;
    final confidence = result.meanConfidence;
    final lowShare = result.lowConfidenceShare;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '3. Review and export',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              result.isEmpty
                  ? 'No text was recognized. The image may be blank, rotated or '
                        'too small for the recognition model.'
                  : '${result.words.length} words · '
                        '${confidence == null ? 'confidence not reported' : 'mean confidence ${confidence.toStringAsFixed(0)}%'}',
              key: const Key('ocr-summary'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (lowShare > .2) ...[
              const SizedBox(height: 8),
              Card(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.warning_amber_rounded),
                  title: const Text(
                    'Many words were recognized with low confidence. '
                    'Check them against the image before exporting.',
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              key: const Key('ocr-text'),
              controller: _text,
              minLines: 8,
              maxLines: 24,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(
                labelText: 'Extracted text (editable)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  key: const Key('ocr-copy'),
                  onPressed: _copy,
                  icon: const Icon(Icons.copy_all_outlined),
                  label: const Text('Copy'),
                ),
                FilledButton.icon(
                  key: const Key('ocr-txt'),
                  onPressed: _exportText,
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('Save TXT'),
                ),
                OutlinedButton.icon(
                  key: const Key('ocr-docx'),
                  onPressed: _exportDocx,
                  icon: const Icon(Icons.article_outlined),
                  label: const Text('Save DOCX'),
                ),
                OutlinedButton.icon(
                  key: const Key('ocr-pdf'),
                  onPressed: _exportSearchablePdf,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Searchable PDF'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'The searchable PDF keeps the page image and adds an invisible '
              'layer of the original recognized words; edits above are only '
              'included in TXT or DOCX. The PDF is not an editable document.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
