import 'package:flutter/material.dart';

import '../core/physical_page_limits.dart';
import '../design/design_document.dart';
import '../design/template_catalog.dart';
import '../printing/paper_catalog.dart';

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
  late DesignTemplate _template;

  @override
  void initState() {
    super.initState();
    _template = widget.template;
    final definition = designTemplateDefinition(_template);
    if (_template != DesignTemplate.blank) {
      _width.text = definition.widthMm.toString();
      _height.text = definition.heightMm.toString();
      _preset = paperSheetPresets.length;
      _name.text = definition.label;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _width.dispose();
    _height.dispose();
    super.dispose();
  }

  void _create() {
    if (!_form.currentState!.validate()) return;
    final width = double.parse(_width.text);
    final height = double.parse(_height.text);
    final doc =
        DesignDocument.blank(
          name: _name.text,
          widthMm: width,
          heightMm: height,
        ).copyWith(
          elements: buildDesignTemplateElements(
            _template,
            widthMm: width,
            heightMm: height,
          ),
        );
    Navigator.of(context).pop(doc);
  }

  String? _dimension(String? value) {
    final number = double.tryParse(value ?? '');
    return number == null ||
            !number.isFinite ||
            number < minPhysicalPageMm ||
            number > maxPhysicalPageMm
        ? 'Use 10–2500 mm'
        : null;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(designTemplateDefinition(_template).label),
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
              DropdownButtonFormField<DesignTemplate>(
                key: const Key('design-template-picker'),
                initialValue: _template,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Starting template',
                ),
                items: [
                  for (final item in designTemplateCatalog)
                    DropdownMenuItem(
                      value: item.template,
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  final definition = designTemplateDefinition(value);
                  setState(() {
                    _template = value;
                    _width.text = definition.widthMm.toString();
                    _height.text = definition.heightMm.toString();
                    _preset = paperSheetPresets.length;
                    if (_name.text.trim().isEmpty ||
                        _name.text == 'Untitled design' ||
                        designTemplateCatalog.any(
                          (item) => item.label == _name.text,
                        )) {
                      _name.text = definition.label;
                    }
                  });
                },
              ),
              const SizedBox(height: 8),
              Text(
                designTemplateDefinition(_template).description,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                key: ValueKey(_preset),
                initialValue: _preset,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Canvas preset'),
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
                    child: const Text('Custom size'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _preset = value;
                    if (value < paperSheetPresets.length) {
                      _width.text = paperSheetPresets[value].widthMm.toString();
                      _height.text = paperSheetPresets[value].heightMm
                          .toString();
                    }
                  });
                },
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const Key('canvas-width'),
                      controller: _width,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Width (mm)',
                      ),
                      validator: _dimension,
                      onChanged: (_) =>
                          setState(() => _preset = paperSheetPresets.length),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      key: const Key('canvas-height'),
                      controller: _height,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Height (mm)',
                      ),
                      validator: _dimension,
                      onChanged: (_) =>
                          setState(() => _preset = paperSheetPresets.length),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Swap width and height',
                    onPressed: () => setState(() {
                      final before = _width.text;
                      _width.text = _height.text;
                      _height.text = before;
                      _preset = paperSheetPresets.length;
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
