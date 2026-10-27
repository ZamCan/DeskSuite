import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../image_engine/image_processing_service.dart';
import 'file_gateway.dart';

/// A first connected, local-only photo workflow built on the shared image engine.
/// Every operation creates a new output; the imported source remains unchanged.
class PhotoStudioScreen extends StatefulWidget {
  const PhotoStudioScreen({super.key, required this.files});
  final FileGateway files;

  @override
  State<PhotoStudioScreen> createState() => _PhotoStudioScreenState();
}

class _PhotoStudioScreenState extends State<PhotoStudioScreen> {
  final ImageProcessingService _engine = const ImageProcessingService();
  Uint8List? _source;
  Uint8List? _working;
  ImageMetadata? _sourceInfo;
  ImageMetadata? _workingInfo;
  DeskImageFormat _format = DeskImageFormat.jpeg;
  int _quality = 92;
  bool _busy = false;
  String? _error;
  final TextEditingController _width = TextEditingController();
  final TextEditingController _height = TextEditingController();

  @override
  void dispose() {
    _width.dispose();
    _height.dispose();
    super.dispose();
  }

  void _message(String value) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _pick() async {
    try {
      final bytes = await widget.files.pickImage();
      if (bytes == null || !mounted) return;
      setState(() {
        _busy = true;
        _error = null;
      });
      final metadata = _engine.inspect(bytes);
      if (!mounted) return;
      setState(() {
        _source = bytes;
        _working = bytes;
        _sourceInfo = metadata;
        _workingInfo = metadata;
        _width.text = metadata.width.toString();
        _height.text = metadata.height.toString();
        _format = supportedImageOutputFormats.contains(metadata.format)
            ? metadata.format
            : DeskImageFormat.jpeg;
      });
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _apply(ImageProcessingResult result) {
    setState(() {
      _working = result.bytes;
      _workingInfo = result.metadata;
      _error = result.warnings.isEmpty ? null : result.warnings.join(' ');
    });
  }

  Future<void> _rotate(int degrees) async {
    final source = _working;
    if (source == null || _busy) return;
    setState(() => _busy = true);
    try {
      final result = _engine.rotate(source: source, degrees: degrees, outputFormat: _format, quality: _quality);
      _apply(result);
      _width.text = result.metadata.width.toString();
      _height.text = result.metadata.height.toString();
    } catch (error) {
      setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resize() async {
    final source = _working;
    final width = int.tryParse(_width.text.trim());
    final height = int.tryParse(_height.text.trim());
    if (source == null || _busy) return;
    if (width == null || height == null || width < 1 || height < 1) {
      setState(() => _error = 'Enter positive whole-number pixel dimensions.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _apply(_engine.resize(source: source, width: width, height: height, preserveAspectRatio: true, outputFormat: _format, quality: _quality));
      final info = _workingInfo!;
      _width.text = info.width.toString();
      _height.text = info.height.toString();
    } catch (error) {
      setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export() async {
    final bytes = _working;
    final info = _workingInfo;
    if (bytes == null || info == null || _busy) return;
    setState(() => _busy = true);
    try {
      // Re-encode to the selected format even if the last edit used another one.
      final encoded = _engine.rotate(source: bytes, degrees: 0, outputFormat: _format, quality: _quality);
      final extension = switch (_format) {
        DeskImageFormat.png => 'png',
        DeskImageFormat.jpeg => 'jpg',
        DeskImageFormat.bmp => 'bmp',
        DeskImageFormat.gif => 'gif',
        DeskImageFormat.webp || DeskImageFormat.unknown =>
          throw StateError('Unsupported output format.'),
      };
      final saved = await widget.files.save(
        name: 'desksuite-photo.$extension',
        bytes: encoded.bytes,
        mimeType: switch (_format) {
          DeskImageFormat.png => 'image/png',
          DeskImageFormat.jpeg => 'image/jpeg',
          DeskImageFormat.bmp => 'image/bmp',
          DeskImageFormat.gif => 'image/gif',
          DeskImageFormat.webp || DeskImageFormat.unknown =>
            throw StateError('Unsupported output format.'),
        },
      );
      if (saved) _message('Edited image exported. Your original file was not changed.');
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final info = _workingInfo;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Photo Studio', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('Local image tools for preparing photos and artwork. Source files are preserved.', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 20),
        Wrap(spacing: 10, runSpacing: 10, children: [
          FilledButton.icon(onPressed: _busy ? null : _pick, icon: const Icon(Icons.add_photo_alternate_outlined), label: const Text('Open image')),
          OutlinedButton.icon(onPressed: _source == null || _busy ? null : () {
            setState(() {
              _working = _source;
              _workingInfo = _sourceInfo;
              _error = null;
              _width.text = _sourceInfo!.width.toString();
              _height.text = _sourceInfo!.height.toString();
            });
          }, icon: const Icon(Icons.restart_alt), label: const Text('Reset edits')),
        ]),
        const SizedBox(height: 18),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Material(color: scheme.errorContainer, borderRadius: BorderRadius.circular(12), child: Padding(padding: const EdgeInsets.all(12), child: Text(_error!, style: TextStyle(color: scheme.onErrorContainer)))),
        ],
        const SizedBox(height: 16),
        Container(
          constraints: const BoxConstraints(minHeight: 210, maxHeight: 430),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: scheme.outlineVariant),
          ),
          alignment: Alignment.center,
          child: _working == null
              ? const Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.image_search_outlined, size: 42),
                      SizedBox(height: 12),
                      Text('Open a photo to begin'),
                    ],
                  ),
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: InteractiveViewer(
                    minScale: .5,
                    maxScale: 5,
                    child: Image.memory(
                      _working!,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                      errorBuilder: (context, error, stackTrace) =>
                          const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Preview could not be decoded.'),
                      ),
                    ),
                  ),
                ),
        ),
        if (info != null) ...[
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _Metric(label: 'Dimensions', value: '${info.width} × ${info.height} px'),
            _Metric(label: 'Resolution', value: '${info.megapixels.toStringAsFixed(2)} MP'),
            _Metric(label: 'Output size', value: '${(info.byteLength / 1024).toStringAsFixed(1)} KB'),
          ]),
          const SizedBox(height: 18),
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Transform', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Wrap(spacing: 10, runSpacing: 10, children: [
              OutlinedButton.icon(onPressed: _busy ? null : () => _rotate(270), icon: const Icon(Icons.rotate_left), label: const Text('Rotate left')),
              OutlinedButton.icon(onPressed: _busy ? null : () => _rotate(90), icon: const Icon(Icons.rotate_right), label: const Text('Rotate right')),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: TextField(controller: _width, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Width (px)', border: OutlineInputBorder(), isDense: true))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: _height, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Height (px)', border: OutlineInputBorder(), isDense: true))),
            ]),
            const SizedBox(height: 10),
            Align(alignment: Alignment.centerRight, child: FilledButton.tonal(onPressed: _busy ? null : _resize, child: const Text('Resize · preserve aspect ratio'))),
          ]))),
          const SizedBox(height: 12),
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Export copy', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            DropdownButtonFormField<DeskImageFormat>(
              initialValue: _format,
              decoration: const InputDecoration(labelText: 'File format', border: OutlineInputBorder()),
              items: supportedImageOutputFormats.map((format) => DropdownMenuItem(value: format, child: Text(format.name.toUpperCase()))).toList(),
              onChanged: _busy ? null : (value) { if (value != null) setState(() => _format = value); },
            ),
            if (_format == DeskImageFormat.jpeg) ...[
              const SizedBox(height: 12),
              Text('JPEG quality: $_quality%'),
              Slider(value: _quality.toDouble(), min: 40, max: 100, divisions: 12, label: '$_quality%', onChanged: _busy ? null : (value) => setState(() => _quality = value.round())),
            ],
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _busy ? null : _export, icon: const Icon(Icons.save_alt), label: const Text('Export edited copy'))),
          ]))),
        ],
        const SizedBox(height: 24),
        Text('Engine note: this first workflow handles local raster images (PNG, JPEG, BMP and GIF). Camera capture, document-edge detection, perspective correction, OCR and passport-photo templates are separate engine stages and are not claimed as implemented here.', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: Theme.of(context).textTheme.labelSmall),
      const SizedBox(height: 3),
      Text(value, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
    ]),
  );
}
