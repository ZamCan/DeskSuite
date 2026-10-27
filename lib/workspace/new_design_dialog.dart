import 'package:flutter/material.dart';

import '../core/ids.dart';
import '../design/design_document.dart';

enum DesignTemplate { blank, editorial }

class _Preset {
  const _Preset(this.label, this.width, this.height);
  final String label;
  final double width;
  final double height;
}

const _presets = <_Preset>[
  _Preset('A4 · 210 × 297 mm', 210, 297),
  _Preset('A5 · 148 × 210 mm', 148, 210),
  _Preset('A3 · 297 × 420 mm', 297, 420),
  _Preset('Business card · 85 × 55 mm', 85, 55),
  _Preset('Square · 108 × 108 mm', 108, 108),
  _Preset('Custom size', 210, 297),
];

class NewDesignDialog extends StatefulWidget {
  const NewDesignDialog({super.key, this.template = DesignTemplate.blank});
  final DesignTemplate template;
  @override
  State<NewDesignDialog> createState() => _NewDesignDialogState();
}

class _NewDesignDialogState extends State<NewDesignDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(text: 'Untitled design');
  final _width = TextEditingController(text: '210');
  final _height = TextEditingController(text: '297');
  int _preset = 0;

  @override
  void dispose() {
    _name.dispose();
    _width.dispose();
    _height.dispose();
    super.dispose();
  }

  void _create() {
    if (!_form.currentState!.validate()) return;
    var doc = DesignDocument.blank(
      name: _name.text,
      widthMm: double.parse(_width.text),
      heightMm: double.parse(_height.text),
    );
    if (widget.template == DesignTemplate.editorial) {
      final w = doc.widthMm;
      final h = doc.heightMm;
      doc = doc.copyWith(
        elements: [
          DesignElement(
            id: newId(),
            kind: ElementKind.rectangle,
            x: 0,
            y: 0,
            width: w,
            height: h * .34,
            color: 0xffbd694f,
          ),
          DesignElement(
            id: newId(),
            kind: ElementKind.text,
            x: w * .08,
            y: h * .42,
            width: w * .84,
            height: h * .18,
            text: 'YOUR\nHEADLINE',
            fontSizePt: (w * .19).clamp(12, 90),
            bold: true,
          ),
          DesignElement(
            id: newId(),
            kind: ElementKind.text,
            x: w * .08,
            y: h * .72,
            width: w * .78,
            height: h * .12,
            text: 'Add your details here.',
            fontSizePt: (w * .065).clamp(8, 30),
          ),
        ],
      );
    }
    Navigator.of(context).pop(doc);
  }

  String? _dimension(String? value) {
    final number = double.tryParse(value ?? '');
    return number == null || !number.isFinite || number < 10 || number > 1200
        ? 'Use 10–1200 mm'
        : null;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.template == DesignTemplate.blank
          ? 'New design'
          : 'Editorial poster',
    ),
    content: SizedBox(
      width: 430,
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Set up your canvas. You can change the objects later.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              TextFormField(
                key: const Key('project-name'),
                controller: _name,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Project name'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a project name'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                key: ValueKey(_preset),
                initialValue: _preset,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Canvas preset'),
                items: [
                  for (var i = 0; i < _presets.length; i++)
                    DropdownMenuItem(
                      value: i,
                      child: Text(
                        _presets[i].label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _preset = value;
                    if (value != _presets.length - 1) {
                      _width.text = _presets[value].width.toStringAsFixed(0);
                      _height.text = _presets[value].height.toStringAsFixed(0);
                    }
                  });
                },
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _width,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Width (mm)',
                      ),
                      validator: _dimension,
                      onChanged: (_) =>
                          setState(() => _preset = _presets.length - 1),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _height,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Height (mm)',
                      ),
                      validator: _dimension,
                      onChanged: (_) =>
                          setState(() => _preset = _presets.length - 1),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Swap width and height',
                    onPressed: () => setState(() {
                      final before = _width.text;
                      _width.text = _height.text;
                      _height.text = before;
                      _preset = _presets.length - 1;
                    }),
                    icon: const Icon(Icons.swap_horiz),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const Key('create-design'),
        onPressed: _create,
        child: const Text('Create design'),
      ),
    ],
  );
}
