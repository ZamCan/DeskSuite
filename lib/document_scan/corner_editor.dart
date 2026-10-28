import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../images/photo_processor.dart';
import 'page_corner_suggestion.dart';
import 'scan_processor.dart';

/// Reviewable four-corner editor with a numeric alternative to dragging.
class CornerEditor extends StatefulWidget {
  const CornerEditor({super.key, required this.photo, this.suggester});
  final PhotoResult photo;
  final Future<ScanCorners?> Function(PhotoResult)? suggester;

  @override
  State<CornerEditor> createState() => _CornerEditorState();
}

class _CornerEditorState extends State<CornerEditor> {
  List<ScanPoint> points = const ScanCorners.full().points;
  String? error, notice;
  bool suggesting = false;

  ScanCorners get corners =>
      ScanCorners(points[0], points[1], points[2], points[3]);

  Future<void> suggest() async {
    if (suggesting) return;
    setState(() {
      suggesting = true;
      error = null;
      notice = null;
    });
    try {
      final suggestion =
          await (widget.suggester ?? suggestScanCornersInBackground)(
            widget.photo,
          );
      if (!mounted) return;
      if (suggestion == null) {
        setState(
          () => error = 'No reliable suggestion. Drag the handles or enter coordinates instead.',
        );
      } else {
        // The algorithm can mistake other bright rectangles for paper. Always
        // keep the suggestion editable and require the user's confirmation.
        suggestion.validate();
        setState(() {
          points = suggestion.points;
          notice = 'Suggested corners are approximate. Check and adjust all four before correcting.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Could not suggest corners. Manual adjustment is still available.',
        );
      }
    } finally {
      if (mounted) setState(() => suggesting = false);
    }
  }

  Future<void> coordinates() async {
    final updated = await showDialog<List<ScanPoint>>(
      context: context,
      builder: (_) => _CoordinateDialog(points: points),
    );
    if (updated != null && mounted) {
      setState(() {
        points = updated;
        error = null;
        notice = null;
      });
    }
  }

  void apply() {
    try {
      corners.validate();
      Navigator.pop(context, corners);
    } on FormatException catch (e) {
      setState(() => error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      child: SizedBox(
        width: 680,
        height: math.min(media.height * .86, 760),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: media.height * .24),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Adjust page corners',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          if (suggesting)
                            const SizedBox(
                              width: 48,
                              height: 48,
                              child: Center(
                                child: CircularProgressIndicator(
                                  semanticsLabel: 'Suggesting page corners',
                                ),
                              ),
                            )
                          else
                            IconButton(
                              key: const Key('suggest-corners'),
                              tooltip: 'Suggest corners',
                              onPressed: suggest,
                              icon: const Icon(Icons.auto_fix_high),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Use the wand to suggest corners for a bright page on a darker background, or drag the handles or enter coordinates. Always review all four corners.',
                      ),
                      if (notice != null)
                        Semantics(liveRegion: true, child: Text(notice!)),
                      if (error != null)
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final availableWidth = math.max(
                      1.0,
                      constraints.maxWidth - 48,
                    );
                    final availableHeight = math.max(
                      1.0,
                      constraints.maxHeight - 48,
                    );
                    final scale = math.min(
                      availableWidth / widget.photo.width,
                      availableHeight / widget.photo.height,
                    );
                    final w = widget.photo.width * scale,
                        h = widget.photo.height * scale;
                    final left = (constraints.maxWidth - w) / 2,
                        top = (constraints.maxHeight - h) / 2;
                    final imageRect = Rect.fromLTWH(left, top, w, h);
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fromRect(
                          rect: imageRect,
                          child: Image.memory(
                            widget.photo.bytes,
                            fit: BoxFit.fill,
                            cacheWidth: math.min(widget.photo.width, 1200),
                          ),
                        ),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _CornersPainter(imageRect, points),
                            ),
                          ),
                        ),
                        for (var i = 0; i < 4; i++)
                          Positioned(
                            left: left + points[i].x * w - 24,
                            top: top + points[i].y * h - 24,
                            child: Semantics(
                              label:
                                  '${['Top left', 'Top right', 'Bottom right', 'Bottom left'][i]} corner',
                              hint: 'Drag to adjust, or tap to enter coordinates.',
                              button: true,
                              child: GestureDetector(
                                key: Key('corner-$i'),
                                behavior: HitTestBehavior.opaque,
                                onTap: suggesting ? null : coordinates,
                                onPanUpdate: suggesting
                                    ? null
                                    : (details) => setState(() {
                                        points = List.of(points);
                                        points[i] = ScanPoint(
                                          (points[i].x + details.delta.dx / w)
                                              .clamp(0.0, 1.0),
                                          (points[i].y + details.delta.dy / h)
                                              .clamp(0.0, 1.0),
                                        );
                                        error = null;
                                        notice = null;
                                      }),
                                child: SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: Center(
                                    child: Container(
                                      width: 26,
                                      height: 26,
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '${i + 1}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Enter coordinates',
                    onPressed: suggesting ? null : coordinates,
                    icon: const Icon(Icons.tune),
                  ),
                  IconButton(
                    tooltip: 'Cancel',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      key: const Key('apply-corners'),
                      onPressed: suggesting ? null : apply,
                      child: const Text('Correct page'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CornersPainter extends CustomPainter {
  _CornersPainter(this.rect, this.points);
  final Rect rect;
  final List<ScanPoint> points;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final p = Offset(
        rect.left + points[i].x * rect.width,
        rect.top + points[i].y * rect.height,
      );
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black54
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _CornersPainter oldDelegate) =>
      oldDelegate.rect != rect || oldDelegate.points != points;
}

class _CoordinateDialog extends StatefulWidget {
  const _CoordinateDialog({required this.points});
  final List<ScanPoint> points;
  @override
  State<_CoordinateDialog> createState() => _CoordinateDialogState();
}

class _CoordinateDialogState extends State<_CoordinateDialog> {
  late final List<TextEditingController> values;
  String? error;
  @override
  void initState() {
    super.initState();
    values = [
      for (final p in widget.points)
        TextEditingController(text: (p.x * 100).toStringAsFixed(1)),
      for (final p in widget.points)
        TextEditingController(text: (p.y * 100).toStringAsFixed(1)),
    ];
  }

  @override
  void dispose() {
    for (final c in values) {
      c.dispose();
    }
    super.dispose();
  }

  void apply() {
    final numbers = values.map((c) => double.tryParse(c.text.trim())).toList();
    if (numbers.any((n) => n == null || !n.isFinite || n < 0 || n > 100)) {
      setState(() => error = 'Use percentages from 0 to 100.');
      return;
    }
    final points = List.generate(
      4,
      (i) => ScanPoint(numbers[i]! / 100, numbers[i + 4]! / 100),
    );
    try {
      ScanCorners(points[0], points[1], points[2], points[3]).validate();
      Navigator.pop(context, points);
    } on FormatException catch (e) {
      setState(() => error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Corner coordinates'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Percent from the left (X) and top (Y) of the image.'),
          for (var i = 0; i < 4; i++) ...[
            const SizedBox(height: 12),
            Text(
              [
                '1 · Top left',
                '2 · Top right',
                '3 · Bottom right',
                '4 · Bottom left',
              ][i],
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: values[i],
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'X %'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: values[i + 4],
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Y %'),
                  ),
                ),
              ],
            ),
          ],
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: apply, child: const Text('Use coordinates')),
    ],
  );
}
