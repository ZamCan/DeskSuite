import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../workspace/file_gateway.dart';
import 'image_processing_service.dart';

class ImageToolsScreen extends StatefulWidget {
  const ImageToolsScreen({super.key, required this.files});
  final FileGateway files;

  @override
  State<ImageToolsScreen> createState() => _ImageToolsScreenState();
}

class _ImageToolsScreenState extends State<ImageToolsScreen> {
  final _width = TextEditingController(text: '1024');
  final _height = TextEditingController(text: '1024');
  final _service = ImageProcessingService();
  Uint8List? _source;
  Uint8List? _output;
  final String _sourceName = 'image';
  ImageDimensions? _sourceDimensions;
  int? _outputWidth;
  int? _outputHeight;
  ImageOutputFormat _format = ImageOutputFormat.jpeg;
  double _quality = 85;
  bool _preserveAspect = true;
  bool _processing = false;
  String? _error;

  @override
  void dispose() {
    _width.dispose();
    _height.dispose();
    super.dispose();
  }

  void _message(String value) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
    }
  }

  Future<void> _pickImage() async {
    try {
      final bytes = await widget.files.pickImage();
      if (bytes == null || !mounted) return;
      final dimensions = _service.inspect(bytes);
      setState(() {
        _source = bytes;
        _sourceDimensions = dimensions;
        _width.text = dimensions.width.toString();
        _height.text = dimensions.height.toString();
        _output = null;
        _outputWidth = null;
        _outputHeight = null;
        _error = null;
      });
    } catch (error) {
      setState(() => _error = '$error');
    }
  }

  Future<void> _process() async {
    final source = _source;
    if (source == null) return;
    final width = int.tryParse(_width.text.trim());
    final height = int.tryParse(_height.text.trim());
    if (width == null || height == null) {
      setState(() => _error = 'Enter whole-number pixel dimensions.');
      return;
    }
    setState(() {
      _processing = true;
      _error = null;
      _output = null;
    });
    try {
      final result = await compute<Map<String, Object>, Map<String, Object>>(
        _processImageJob,
        <String, Object>{
          'bytes': source,
          'width': width,
          'height': height,
          'preserveAspect': _preserveAspect,
          'format': _format.name,
          'quality': _quality.round(),
        },
      );
      if (!mounted) return;
      setState(() {
        _output = result['bytes'] as Uint8List;
        _outputWidth = result['width'] as int;
        _outputHeight = result['height'] as int;
      });
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _saveOutput() async {
    final bytes = _output;
    final width = _outputWidth;
    final height = _outputHeight;
    if (bytes == null || width == null || height == null) return;
    final extension = _format == ImageOutputFormat.png ? 'png' : 'jpg';
    try {
      final saved = await widget.files.save(
        name: '${_sourceName}_${width}x${height}.$extension',
        bytes: bytes,
        mimeType: _format == ImageOutputFormat.png ? 'image/png' : 'image/jpeg',
      );
      if (saved) _message('Saved resized image. The source file was left unchanged.');
    } catch (error) {
      _message('Could not save image: $error');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Image tools')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Resize and compress',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Set exact pixel dimensions, compare the result, and export a new file. Your original image is never overwritten.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _processing ? null : _pickImage,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(_source == null ? 'Choose an image' : 'Choose another image'),
                ),
                if (_source != null && _sourceDimensions != null) ...[
                  const SizedBox(height: 18),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 112,
                              height: 112,
                              child: Image.memory(_source!, fit: BoxFit.contain),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Original image', style: TextStyle(fontWeight: FontWeight.w800)),
                                const SizedBox(height: 5),
                                Text('${_sourceDimensions!.width} × ${_sourceDimensions!.height} px'),
                                Text(_formatBytes(_source!.length)),
                                const SizedBox(height: 6),
                                const Text('Choose a target size below.', style: TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('Output dimensions', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _width,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Width (px)'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _height,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Height (px)'),
                        ),
                      ),
                    ],
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Preserve aspect ratio'),
                    subtitle: const Text('Fits inside the target box without stretching.'),
                    value: _preserveAspect,
                    onChanged: _processing ? null : (value) => setState(() => _preserveAspect = value ?? true),
                  ),
                  DropdownButtonFormField<ImageOutputFormat>(
                    initialValue: _format,
                    decoration: const InputDecoration(labelText: 'Output format'),
                    items: const [
                      DropdownMenuItem(value: ImageOutputFormat.jpeg, child: Text('JPEG · smaller files')),
                      DropdownMenuItem(value: ImageOutputFormat.png, child: Text('PNG · lossless')),
                    ],
                    onChanged: _processing ? null : (value) => setState(() {
                      if (value != null) _format = value;
                    }),
                  ),
                  if (_format == ImageOutputFormat.jpeg) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Expanded(child: Text('JPEG quality')),
                        Text('${_quality.round()}%'),
                      ],
                    ),
                    Slider(
                      min: 20,
                      max: 100,
                      divisions: 16,
                      value: _quality,
                      label: '${_quality.round()}%',
                      onChanged: _processing ? null : (value) => setState(() => _quality = value),
                    ),
                  ],
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _processing ? null : _process,
                    icon: _processing
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.tune_rounded),
                    label: Text(_processing ? 'Processing…' : 'Process image'),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Material(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(_error!),
                    ),
                  ),
                ],
                if (_output != null && _outputWidth != null && _outputHeight != null) ...[
                  const SizedBox(height: 22),
                  Text('Processed result', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 300),
                              child: Image.memory(_output!, fit: BoxFit.contain),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text('$_outputWidth × $_outputHeight px · ${_format.name.toUpperCase()}'),
                          Text('Output size: ${_formatBytes(_output!.length)}'),
                          if (_source != null)
                            Text('Size change: ${_sizeChange(_source!.length, _output!.length)}'),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _saveOutput,
                            icon: const Icon(Icons.save_alt_rounded),
                            label: const Text('Save output'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String _sizeChange(int before, int after) {
    if (before == 0) return 'not available';
    final percent = ((after - before) / before * 100);
    final sign = percent > 0 ? '+' : '';
    return '$sign${percent.toStringAsFixed(1)}%';
  }
}

Map<String, Object> _processImageJob(Map<String, Object> input) {
  final formatName = input['format'] as String;
  final format = formatName == 'png' ? ImageOutputFormat.png : ImageOutputFormat.jpeg;
  final result = ImageProcessingService().resizeAndEncode(
    sourceBytes: input['bytes'] as Uint8List,
    targetWidth: input['width'] as int,
    targetHeight: input['height'] as int,
    preserveAspectRatio: input['preserveAspect'] as bool,
    format: format,
    jpegQuality: input['quality'] as int,
  );
  return <String, Object>{
    'bytes': result.bytes,
    'width': result.width,
    'height': result.height,
    'format': result.format.name,
  };
}
