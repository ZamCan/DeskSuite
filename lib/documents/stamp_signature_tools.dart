import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class StampPreset {
  const StampPreset(this.label, this.color);
  final String label;
  final Color color;

  static const values = <StampPreset>[
    StampPreset('DRAFT', Color(0xffb65c35)),
    StampPreset('APPROVED', Color(0xff28784f)),
    StampPreset('PAID', Color(0xff28784f)),
    StampPreset('RECEIVED', Color(0xff315e91)),
    StampPreset('CONFIDENTIAL', Color(0xff8b3434)),
    StampPreset('COPY', Color(0xff69645d)),
    StampPreset('VOID', Color(0xff8b3434)),
  ];
}

enum StampPlacement { topLeft, topCenter, topRight, bottomLeft, bottomCenter, bottomRight }

class StampSpec {
  const StampSpec({
    required this.label,
    required this.color,
    required this.includeDate,
    this.placement = StampPlacement.topCenter,
  });
  final String label;
  final Color color;
  final bool includeDate;
  final StampPlacement placement;

  String textAt(DateTime date) {
    final value = label.trim().toUpperCase();
    if (!includeDate) return value;
    final day = date.day.toString().padLeft(2, '0');
    return '$value\n$day ${_month(date.month)} ${date.year}';
  }

  static String _month(int month) => const [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ][month - 1];
}

Future<StampSpec?> showStampDialog(BuildContext context) =>
    showDialog<StampSpec>(
      context: context,
      builder: (_) => const _StampDialog(),
    );

class _StampDialog extends StatefulWidget {
  const _StampDialog();
  @override
  State<_StampDialog> createState() => _StampDialogState();
}

class _StampDialogState extends State<_StampDialog> {
  StampPreset _selected = StampPreset.values.first;
  final TextEditingController _custom = TextEditingController();
  bool _includeDate = true;
  StampPlacement _placement = StampPlacement.topCenter;

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add a document stamp'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<StampPreset>(
              initialValue: _selected,
              decoration: const InputDecoration(labelText: 'Stamp preset'),
              items: [
                for (final preset in StampPreset.values)
                  DropdownMenuItem(
                    value: preset,
                    child: Text(
                      preset.label,
                      style: TextStyle(
                        color: preset.color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _selected = value);
              },
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Include today’s date'),
              subtitle: const Text('The date is captured when the stamp is placed.'),
              value: _includeDate,
              onChanged: (value) => setState(() => _includeDate = value),
            ),
            DropdownButtonFormField<StampPlacement>(
              initialValue: _placement,
              decoration: const InputDecoration(labelText: 'Placement'),
              items: const [
                DropdownMenuItem(value: StampPlacement.topLeft, child: Text('Top left')),
                DropdownMenuItem(value: StampPlacement.topCenter, child: Text('Top center')),
                DropdownMenuItem(value: StampPlacement.topRight, child: Text('Top right')),
                DropdownMenuItem(value: StampPlacement.bottomLeft, child: Text('Bottom left')),
                DropdownMenuItem(value: StampPlacement.bottomCenter, child: Text('Bottom center')),
                DropdownMenuItem(value: StampPlacement.bottomRight, child: Text('Bottom right')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _placement = value);
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _custom,
              maxLength: 48,
              decoration: const InputDecoration(
                labelText: 'Custom stamp (optional)',
                hintText: 'e.g. FOR REVIEW',
              ),
            ),
            const SizedBox(height: 8),
            AnimatedBuilder(
              animation: _custom,
              builder: (context, _) {
                final label = _custom.text.trim().isEmpty
                    ? _selected.label
                    : _custom.text.trim().toUpperCase();
                final now = DateTime.now();
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _selected.color.withValues(alpha: .08),
                    border: Border.all(
                      color: _selected.color.withValues(alpha: .45),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$label${_includeDate ? '\n${now.day.toString().padLeft(2, '0')} ${StampSpec._month(now.month)} ${now.year}' : ''}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _selected.color,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton.icon(
        onPressed: () {
          final label = _custom.text.trim().isEmpty
              ? _selected.label
              : _custom.text.trim();
          if (label.isEmpty) return;
          Navigator.pop(
            context,
            StampSpec(
              label: label,
              color: _selected.color,
              includeDate: _includeDate,
              placement: _placement,
            ),
          );
        },
        icon: const Icon(Icons.verified_outlined),
        label: const Text('Place stamp'),
      ),
    ],
  );
}

Future<Uint8List?> showSignatureCaptureDialog(BuildContext context) =>
    showDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _SignatureCaptureDialog(),
    );

class _SignatureCaptureDialog extends StatefulWidget {
  const _SignatureCaptureDialog();
  @override
  State<_SignatureCaptureDialog> createState() =>
      _SignatureCaptureDialogState();
}

class _SignatureCaptureDialogState extends State<_SignatureCaptureDialog> {
  final List<List<Offset>> _strokes = <List<Offset>>[];
  List<Offset>? _current;
  Size _canvasSize = Size.zero;

  void _start(Offset point) => setState(() => _current = <Offset>[point]);

  void _move(Offset point) {
    if (_current == null) return;
    setState(() => _current!.add(point));
  }

  void _finish() {
    if (_current != null && _current!.isNotEmpty) {
      _strokes.add(List<Offset>.of(_current!));
    }
    setState(() => _current = null);
  }

  Future<Uint8List?> _makePng() async {
    if (_strokes.every((stroke) => stroke.length < 2) ||
        _canvasSize.width <= 0 ||
        _canvasSize.height <= 0) {
      return null;
    }
    const outputWidth = 1200.0;
    const outputHeight = 400.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()
      ..color = const Color(0xff292824)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final stroke in _strokes) {
      if (stroke.length < 2) continue;
      final path = Path()
        ..moveTo(
          stroke.first.dx / _canvasSize.width * outputWidth,
          stroke.first.dy / _canvasSize.height * outputHeight,
        );
      for (final point in stroke.skip(1)) {
        path.lineTo(
          point.dx / _canvasSize.width * outputWidth,
          point.dy / _canvasSize.height * outputHeight,
        );
      }
      canvas.drawPath(path, paint);
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      outputWidth.toInt(),
      outputHeight.toInt(),
    );
    picture.dispose();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data?.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Create a signature'),
    content: SizedBox(
      width: 500,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Draw with your finger or stylus. The saved signature has a transparent background.',
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              _canvasSize = Size(constraints.maxWidth, 190);
              return Container(
                height: 190,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xfff5f2ec)
                      : Colors.white,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: GestureDetector(
                  key: const Key('signature-drawing-surface'),
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (details) => _start(details.localPosition),
                  onPanUpdate: (details) => _move(details.localPosition),
                  onPanEnd: (_) => _finish(),
                  onPanCancel: _finish,
                  child: CustomPaint(
                    painter: _SignaturePainter(_strokes, _current),
                    child: const SizedBox.expand(),
                  ),
                ),
              );
            },
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => setState(() {
                _strokes.clear();
                _current = null;
              }),
              icon: const Icon(Icons.refresh),
              label: const Text('Clear signature'),
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
      FilledButton.icon(
        onPressed: () async {
          final png = await _makePng();
          if (!context.mounted) return;
          if (png == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Draw a signature before saving.')),
            );
            return;
          }
          Navigator.pop(context, png);
        },
        icon: const Icon(Icons.draw_outlined),
        label: const Text('Use signature'),
      ),
    ],
  );
}

class _SignaturePainter extends CustomPainter {
  const _SignaturePainter(this.strokes, this.current);
  final List<List<Offset>> strokes;
  final List<Offset>? current;

  Iterable<List<Offset>> get _visibleStrokes sync* {
    yield* strokes;
    final active = current;
    if (active != null) yield active;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xff292824)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final stroke in _visibleStrokes) {
      if (stroke.isEmpty) continue;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final point in stroke.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      if (stroke.length == 1) {
        canvas.drawCircle(stroke.first, 1.3, paint..style = PaintingStyle.fill);
        paint.style = PaintingStyle.stroke;
      } else {
        canvas.drawPath(path, paint);
      }
    }
    paint
      ..color = const Color(0xffc9c1b6)
      ..strokeWidth = .7;
    canvas.drawLine(
      Offset(12, size.height - 22),
      Offset(size.width - 12, size.height - 22),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
