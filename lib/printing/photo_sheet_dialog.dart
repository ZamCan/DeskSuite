import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../images/photo_processor.dart';
import 'design_export.dart' show effectiveImageDpi;
import 'photo_sheet.dart';
import 'photo_specifications.dart';

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
  final pageWidth = TextEditingController(text: '101.6');
  final pageHeight = TextEditingController(text: '152.4');
  final photoWidth = TextEditingController(text: '35');
  final photoHeight = TextEditingController(text: '45');
  final margin = TextEditingController(text: '10');
  final spacing = TextEditingController(text: '3');
  final copies = TextEditingController(text: '8');
  // Small-format photo paper is a useful starting point; A4/A5/custom stay explicit choices.
  int preset = 3;
  int photoPreset = customPhotoSpecificationIndex;

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

  PhotoSheetSpec _spec() {
    if (photoWidth.text.trim().isEmpty || photoHeight.text.trim().isEmpty) {
      throw const FormatException(
        'Enter the required finished photo width and height in mm.',
      );
    }
    return PhotoSheetSpec(
    pageWidthMm: double.parse(pageWidth.text),
    pageHeightMm: double.parse(pageHeight.text),
    photoWidthMm: double.parse(photoWidth.text),
    photoHeightMm: double.parse(photoHeight.text),
    marginMm: double.parse(margin.text),
    spacingMm: double.parse(spacing.text),
    copies: int.parse(copies.text),
  )..positions();
  }

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
      if (photoDimension) photoPreset = customPhotoSpecificationIndex;
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
      if (value < photoSpecifications.length) {
        final profile = photoSpecifications[value];
        if (profile.hasPublishedDimensions) {
          photoWidth.text = '${profile.widthMm}';
          photoHeight.text = '${profile.heightMm}';
        } else {
          // Do not leave a previous/generic size looking like an authority rule.
          photoWidth.clear();
          photoHeight.clear();
        }
      }
    });
  }

  PhotoSpecification? get _selectedSpecification =>
      photoPreset < photoSpecifications.length
          ? photoSpecifications[photoPreset]
          : null;

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
                'Arrange finished photos on a selected print medium. Photo dimensions and sheet size are separate choices; this layout does not certify passport/ID compliance. Check printer margins, supported media and scale before production.',
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
                items: [
                  for (var i = 0; i < photoSpecifications.length; i++)
                    DropdownMenuItem(
                      value: i,
                      child: Text(
                        photoSpecifications[i].label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  DropdownMenuItem(
                    value: customPhotoSpecificationIndex,
                    child: const Text('Custom / generic layout size'),
                  ),
                ],
                onChanged: _selectPhotoPreset,
              ),
              const SizedBox(height: 4),
              if (_selectedSpecification case final profile?) ...[
                Text(
                  '${profile.authority} · ${profile.documentType}',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  profile.hasPublishedDimensions
                      ? '${profile.dimensionRule == PhotoDimensionRule.maximum ? 'Published maximum envelope' : profile.dimensionRule == PhotoDimensionRule.recommended ? 'International guidance / recommended print size' : 'Published print size'}: ${profile.widthMm} × ${profile.heightMm} mm'
                      : 'Physical print dimensions are not stated in this source. Do not infer an official size.',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  'Background: ${profile.background}. ${profile.notes}',
                  style: const TextStyle(fontSize: 12),
                ),
                if (profile.headHeightMinMm != null)
                  Text(
                    'Head height: ${profile.headHeightMinMm}–${profile.headHeightMaxMm} mm from chin to crown.',
                    style: const TextStyle(fontSize: 12),
                  ),
                if (profile.headHeightMinFraction != null)
                  Text(
                    'ICAO portrait guidance: head height ${(profile.headHeightMinFraction! * 100).round()}–${(profile.headHeightMaxFraction! * 100).round()}% of image height.',
                    style: const TextStyle(fontSize: 12),
                  ),
                if (profile.maxFileBytes != null)
                  Text(
                    'Digital upload limit: ${(profile.maxFileBytes! / 1024).round()} KB · formats: ${profile.fileFormats.join(', ')}.',
                    style: const TextStyle(fontSize: 12),
                  ),
                Text(
                  'Source: ${profile.sourceTitle} · verified ${profile.verifiedOn}. Check the authority for current rules.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                SelectableText(profile.sourceUrl),
              ] else
                const Text(
                  'Custom dimensions are for layout only, not an official passport or ID specification. Confirm the issuing authority’s size, crop, background and digital-upload rules.',
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
