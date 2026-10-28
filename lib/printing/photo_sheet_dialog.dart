import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../images/photo_processor.dart';
import 'design_export.dart' show effectiveImageDpi;
import 'photo_sheet.dart';
import 'photo_specifications.dart';

/// Common sheet/media presets. These describe the physical sheet, not
/// finished passport/ID-photo dimensions or printer-supported media.
const paperSheetPresets = <({String label, double widthMm, double heightMm})>[
  (label: 'A4 portrait — 210 × 297 mm', widthMm: 210, heightMm: 297),
  (label: 'A4 landscape — 297 × 210 mm', widthMm: 297, heightMm: 210),
  (label: 'A5 portrait — 148 × 210 mm', widthMm: 148, heightMm: 210),
  (label: '4 × 6 inch photo — 101.6 × 152.4 mm', widthMm: 101.6, heightMm: 152.4),
  (label: 'A0 poster — 841 × 1189 mm', widthMm: 841, heightMm: 1189),
  (label: 'A1 poster — 594 × 841 mm', widthMm: 594, heightMm: 841),
  (label: 'A2 poster — 420 × 594 mm', widthMm: 420, heightMm: 594),
  (label: 'A3 — 297 × 420 mm', widthMm: 297, heightMm: 420),
  (label: 'A6 — 105 × 148 mm', widthMm: 105, heightMm: 148),
  (label: 'A7 — 74 × 105 mm', widthMm: 74, heightMm: 105),
  (label: 'A8 — 52 × 74 mm', widthMm: 52, heightMm: 74),
  (label: 'A9 — 37 × 52 mm', widthMm: 37, heightMm: 52),
  (label: 'A10 — 26 × 37 mm', widthMm: 26, heightMm: 37),
  (label: 'B0 poster — 1000 × 1414 mm', widthMm: 1000, heightMm: 1414),
  (label: 'B1 poster — 707 × 1000 mm', widthMm: 707, heightMm: 1000),
  (label: 'B2 poster — 500 × 707 mm', widthMm: 500, heightMm: 707),
  (label: 'B3 — 353 × 500 mm', widthMm: 353, heightMm: 500),
  (label: 'B4 — 250 × 353 mm', widthMm: 250, heightMm: 353),
  (label: 'B5 — 176 × 250 mm', widthMm: 176, heightMm: 250),
  (label: 'B6 — 125 × 176 mm', widthMm: 125, heightMm: 176),
  (label: 'B7 — 88 × 125 mm', widthMm: 88, heightMm: 125),
  (label: 'B8 — 62 × 88 mm', widthMm: 62, heightMm: 88),
  (label: 'B9 — 44 × 62 mm', widthMm: 44, heightMm: 62),
  (label: 'B10 — 31 × 44 mm', widthMm: 31, heightMm: 44),
  (label: 'US Letter — 8.5 × 11 in', widthMm: 215.9, heightMm: 279.4),
  (label: 'US Legal — 8.5 × 14 in', widthMm: 215.9, heightMm: 355.6),
  (label: 'US Tabloid — 11 × 17 in', widthMm: 279.4, heightMm: 431.8),
  (label: 'US Ledger — 17 × 11 in', widthMm: 431.8, heightMm: 279.4),
  (label: 'ANSI E — 34 × 44 in poster', widthMm: 863.6, heightMm: 1117.6),
  (label: 'Photo 3.5 × 5 in', widthMm: 88.9, heightMm: 127),
  (label: 'Photo 5 × 7 in', widthMm: 127, heightMm: 177.8),
  (label: 'Photo 8 × 10 in', widthMm: 203.2, heightMm: 254),
  (label: 'Poster 12 × 18 in', widthMm: 304.8, heightMm: 457.2),
  (label: 'Poster 18 × 24 in', widthMm: 457.2, heightMm: 609.6),
  (label: 'Poster 24 × 36 in', widthMm: 609.6, heightMm: 914.4),
  (label: 'Large format 36 × 48 in', widthMm: 914.4, heightMm: 1219.2),
  (label: 'Large format 48 × 72 in', widthMm: 1219.2, heightMm: 1828.8),
];

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
      if (pageDimension) preset = paperSheetPresets.length;
      if (photoDimension) photoPreset = customPhotoSpecificationIndex;
    }),
  );

  void _selectPreset(int? value) {
    if (value == null) return;
    setState(() {
      preset = value;
      if (value < paperSheetPresets.length) {
        final size = paperSheetPresets[value];
        pageWidth.text = '${size.widthMm}';
        pageHeight.text = '${size.heightMm}';
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
