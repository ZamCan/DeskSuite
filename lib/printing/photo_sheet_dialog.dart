import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../images/photo_processor.dart';
import 'design_export.dart' show effectiveImageDpi;
import 'photo_sheet.dart';

class PhotoSheetChoice {
  const PhotoSheetChoice(this.spec, {required this.print});
  final PhotoSheetSpec spec;
  final bool print;
}

class PhotoSheetDialog extends StatefulWidget {
  const PhotoSheetDialog({super.key, required this.photo});
  final PhotoResult photo;
  @override
  State<PhotoSheetDialog> createState() => _PhotoSheetDialogState();
}

class _PhotoSheetDialogState extends State<PhotoSheetDialog> {
  final pageWidth = TextEditingController(text: '210');
  final pageHeight = TextEditingController(text: '297');
  final photoWidth = TextEditingController(text: '35');
  final photoHeight = TextEditingController(text: '45');
  final margin = TextEditingController(text: '10');
  final spacing = TextEditingController(text: '3');
  final copies = TextEditingController(text: '8');
  int preset = 0;
  int photoPreset = 0;

  @override
  void dispose() {
    for (final controller in [
      pageWidth,
      pageHeight,
      photoWidth,
      photoHeight,
      margin,
      spacing,
      copies,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  PhotoSheetSpec _spec() => PhotoSheetSpec(
    pageWidthMm: double.parse(pageWidth.text),
    pageHeightMm: double.parse(pageHeight.text),
    photoWidthMm: double.parse(photoWidth.text),
    photoHeightMm: double.parse(photoHeight.text),
    marginMm: double.parse(margin.text),
    spacingMm: double.parse(spacing.text),
    copies: int.parse(copies.text),
  )..positions();

  Widget _field(
    String label,
    String key,
    TextEditingController controller, {
    bool integer = false,
    bool pageDimension = false,
    bool photoDimension = false,
  }) => TextField(
    key: Key(key),
    controller: controller,
    keyboardType: TextInputType.numberWithOptions(decimal: !integer),
    decoration: InputDecoration(labelText: label),
    onChanged: (_) => setState(() {
      if (pageDimension) preset = 4;
      if (photoDimension) photoPreset = 4;
    }),
  );

  void _selectPreset(int? value) {
    if (value == null) return;
    setState(() {
      preset = value;
      final size = switch (value) {
        0 => (210.0, 297.0),
        1 => (297.0, 210.0),
        2 => (148.0, 210.0),
        3 => (101.6, 152.4),
        _ => (0.0, 0.0),
      };
      if (value != 4) {
        pageWidth.text = '${size.$1}';
        pageHeight.text = '${size.$2}';
      }
    });
  }

  void _selectPhotoPreset(int? value) {
    if (value == null) return;
    setState(() {
      photoPreset = value;
      final size = switch (value) {
        0 => (35.0, 45.0),
        1 => (50.8, 50.8),
        2 => (30.0, 40.0),
        3 => (40.0, 50.0),
        _ => (0.0, 0.0),
      };
      if (value != 4) {
        photoWidth.text = '${size.$1}';
        photoHeight.text = '${size.$2}';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    PhotoSheetSpec? spec;
    String? problem;
    try {
      spec = _spec();
    } catch (error) {
      problem = error is FormatException
          ? error.message.toString()
          : 'Enter valid dimensions and copy count.';
    }
    final valid = spec;
    return AlertDialog(
      title: const Text('Photo sheet'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Place repeated copies on one physical page. This is a layout aid, not an ID-photo compliance check.',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                key: ValueKey(preset),
                initialValue: preset,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Paper preset'),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('A4 portrait')),
                  DropdownMenuItem(value: 1, child: Text('A4 landscape')),
                  DropdownMenuItem(value: 2, child: Text('A5 portrait')),
                  DropdownMenuItem(
                    value: 3,
                    child: Text('4 × 6 inch portrait'),
                  ),
                  DropdownMenuItem(value: 4, child: Text('Custom')),
                ],
                onChanged: _selectPreset,
              ),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      'Page width (mm)',
                      'sheet-page-width',
                      pageWidth,
                      pageDimension: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(
                      'Page height (mm)',
                      'sheet-page-height',
                      pageHeight,
                      pageDimension: true,
                    ),
                  ),
                ],
              ),
              DropdownButtonFormField<int>(
                key: ValueKey('photo-size-$photoPreset'),
                initialValue: photoPreset,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Photo size preset (editable)',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 0,
                    child: Text('35 × 45 mm · example, not universal'),
                  ),
                  DropdownMenuItem(
                    value: 1,
                    child: Text('2 × 2 in / 50.8 × 50.8 mm · example'),
                  ),
                  DropdownMenuItem(
                    value: 2,
                    child: Text('30 × 40 mm · example'),
                  ),
                  DropdownMenuItem(
                    value: 3,
                    child: Text('40 × 50 mm · example'),
                  ),
                  DropdownMenuItem(value: 4, child: Text('Custom size')),
                ],
                onChanged: _selectPhotoPreset,
              ),
              const SizedBox(height: 4),
              const Text(
                'These are layout examples, not official passport or ID rules. Confirm the receiving authority’s current dimensions, crop and background requirements.',
                style: TextStyle(fontSize: 12),
              ),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      'Photo width (mm)',
                      'sheet-photo-width',
                      photoWidth,
                      photoDimension: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(
                      'Photo height (mm)',
                      'sheet-photo-height',
                      photoHeight,
                      photoDimension: true,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: _field('Margin (mm)', 'sheet-margin', margin),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field('Spacing (mm)', 'sheet-spacing', spacing),
                  ),
                ],
              ),
              _field('Copies', 'sheet-copies', copies, integer: true),
              const SizedBox(height: 12),
              if (problem != null)
                Text(
                  problem,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                )
              else if (valid != null) ...[
                Text(
                  '${valid.capacity} fit on this page · estimated image detail ${effectiveImageDpi(widget.photo.width, widget.photo.height, valid.photoWidthMm, valid.photoHeightMm).round()} dpi',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Layout preview: images fit inside each frame; printer margins can differ.',
                ),
                const SizedBox(height: 8),
                Center(
                  child: SizedBox(
                    height: 180,
                    child: AspectRatio(
                      aspectRatio: valid.pageWidthMm / valid.pageHeightMm,
                      child: LayoutBuilder(
                        builder: (context, constraints) => DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.black26),
                          ),
                          child: Stack(
                            children: [
                              for (final position in valid.positions())
                                Positioned(
                                  left:
                                      position.leftMm /
                                      valid.pageWidthMm *
                                      constraints.maxWidth,
                                  top:
                                      position.topMm /
                                      valid.pageHeightMm *
                                      constraints.maxHeight,
                                  width:
                                      valid.photoWidthMm /
                                      valid.pageWidthMm *
                                      constraints.maxWidth,
                                  height:
                                      valid.photoHeightMm /
                                      valid.pageHeightMm *
                                      constraints.maxHeight,
                                  child: Image.memory(
                                    widget.photo.bytes,
                                    fit: BoxFit.contain,
                                    cacheWidth: math.min(
                                      widget.photo.width,
                                      400,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        OutlinedButton(
          onPressed: valid == null
              ? null
              : () => Navigator.pop(
                  context,
                  PhotoSheetChoice(valid, print: false),
                ),
          child: const Text('Export PDF'),
        ),
        FilledButton(
          onPressed: valid == null
              ? null
              : () => Navigator.pop(
                  context,
                  PhotoSheetChoice(valid, print: true),
                ),
          child: const Text('Print'),
        ),
      ],
    );
  }
}
