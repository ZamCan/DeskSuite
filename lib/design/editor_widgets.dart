import 'package:flutter/material.dart';

import '../app/theme.dart';
import 'design_controller.dart';
import 'design_document.dart';

class EditorToolButton extends StatelessWidget {
  const EditorToolButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 76,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 23),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    ),
  );
}

class ObjectInspector extends StatelessWidget {
  const ObjectInspector({
    super.key,
    required this.controller,
    required this.onEditText,
    required this.onFillPhotoSlot,
    required this.onDelete,
  });
  final DesignController controller;
  final VoidCallback onEditText;
  final VoidCallback onFillPhotoSlot;
  final VoidCallback onDelete;
  static const colors = <int>[
    0xff292824,
    0xffbd694f,
    0xffc29b62,
    0xff87977b,
    0xff586c75,
    0xffefe7dc,
    0xffffffff,
  ];
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final item = controller.selected;
      if (item == null) {
        return const SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('No object selected.'),
          ),
        );
      }
      void rotate(double delta) => controller.updateSelected(
        (e) => e.copyWith(rotation: (e.rotation + delta) % 360),
      );
      void resize(double scale) => controller.updateSelected(
        (e) => e.copyWith(
          width: (e.width * scale).clamp(5.0, 4000.0),
          height: (e.height * scale).clamp(5.0, 4000.0),
        ),
      );
      Widget action(IconData icon, String tip, VoidCallback callback) =>
          IconButton.outlined(
            tooltip: tip,
            onPressed: callback,
            icon: Icon(icon, size: 20),
          );
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Edit ${item.kind.name}',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${item.width.toStringAsFixed(1)} × ${item.height.toStringAsFixed(1)} mm',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  action(Icons.copy_outlined, 'Duplicate object', () {
                    try {
                      controller.duplicateSelected();
                    } catch (error) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text('$error')));
                    }
                  }),
                  const SizedBox(width: 8),
                  action(Icons.delete_outline, 'Delete object', onDelete),
                ],
              ),
              if (item.kind == ElementKind.rectangle &&
                  item.width == 35 && item.height == 45 &&
                  controller.document.elements.any((element) =>
                    element.kind == ElementKind.text &&
                    element.text.contains('35 × 45 mm') &&
                    element.x >= item.x && element.x < item.x + item.width &&
                    element.y >= item.y && element.y < item.y + item.height
                  )) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  key: const Key('fill-photo-slot'),
                  onPressed: onFillPhotoSlot,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Fill photo slot with image'),
                ),
              ],
              if (item.kind == ElementKind.text) ...[
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: onEditText,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit text'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Text size & style',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    action(
                      Icons.remove,
                      'Smaller text',
                      () => controller.updateSelected(
                        (e) => e.copyWith(
                          fontSizePt: (e.fontSizePt - 2).clamp(4.0, 500.0),
                        ),
                      ),
                    ),
                    Text('${item.fontSizePt.toStringAsFixed(0)} pt'),
                    action(
                      Icons.add,
                      'Larger text',
                      () => controller.updateSelected(
                        (e) => e.copyWith(
                          fontSizePt: (e.fontSizePt + 2).clamp(4.0, 500.0),
                        ),
                      ),
                    ),
                    action(
                      Icons.format_bold,
                      'Toggle bold',
                      () => controller.updateSelected(
                        (e) => e.copyWith(bold: !e.bold),
                      ),
                    ),
                    action(
                      Icons.format_align_left,
                      'Align text left',
                      () => controller.updateSelected(
                        (e) => e.copyWith(textAlignment: TextAlignment.left),
                      ),
                    ),
                    action(
                      Icons.format_align_center,
                      'Align text center',
                      () => controller.updateSelected(
                        (e) => e.copyWith(textAlignment: TextAlignment.center),
                      ),
                    ),
                    action(
                      Icons.format_align_right,
                      'Align text right',
                      () => controller.updateSelected(
                        (e) => e.copyWith(textAlignment: TextAlignment.right),
                      ),
                    ),
                  ],
                ),
              ],
              if (item.kind != ElementKind.image) ...[
                const SizedBox(height: 20),
                const Text(
                  'Colour',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    for (final color in colors)
                      Semantics(
                        label: 'Choose colour ${color.toRadixString(16)}',
                        button: true,
                        child: InkWell(
                          onTap: () => controller.updateSelected(
                            (e) => e.copyWith(color: color),
                          ),
                          borderRadius: BorderRadius.circular(30),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Color(color),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: item.color == color
                                    ? accent
                                    : const Color(0xffd8d1c8),
                                width: item.color == color ? 3 : 1,
                              ),
                            ),
                            child: item.color == color
                                ? Icon(
                                    Icons.check,
                                    size: 18,
                                    color:
                                        color == 0xffffffff ||
                                            color == 0xffefe7dc
                                        ? ink
                                        : Colors.white,
                                  )
                                : null,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              const Text(
                'Transform & arrange',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  action(
                    Icons.rotate_left,
                    'Rotate left 15 degrees',
                    () => rotate(-15),
                  ),
                  action(
                    Icons.rotate_right,
                    'Rotate right 15 degrees',
                    () => rotate(15),
                  ),
                  action(Icons.remove, 'Reduce object size', () => resize(.9)),
                  action(Icons.add, 'Increase object size', () => resize(1.1)),
                  action(
                    Icons.vertical_align_bottom,
                    'Send backward',
                    () => controller.reorder(-1),
                  ),
                  action(
                    Icons.vertical_align_top,
                    'Bring forward',
                    () => controller.reorder(1),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Align on page',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  action(
                    Icons.align_horizontal_left,
                    'Align object left',
                    () => controller.alignHorizontal(TextAlignment.left),
                  ),
                  action(
                    Icons.align_horizontal_center,
                    'Center object',
                    () => controller.alignHorizontal(TextAlignment.center),
                  ),
                  action(
                    Icons.align_horizontal_right,
                    'Align object right',
                    () => controller.alignHorizontal(TextAlignment.right),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

class EditTextDialog extends StatefulWidget {
  const EditTextDialog({super.key, required this.initialText});
  final String initialText;
  @override
  State<EditTextDialog> createState() => _EditTextDialogState();
}

class _EditTextDialogState extends State<EditTextDialog> {
  late final TextEditingController field;
  @override
  void initState() {
    super.initState();
    field = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Edit text'),
    content: SizedBox(
      width: 420,
      child: TextField(
        key: const Key('edit-text-field'),
        controller: field,
        autofocus: true,
        maxLength: 4000,
        minLines: 2,
        maxLines: 6,
        decoration: const InputDecoration(labelText: 'Text'),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, field.text),
        child: const Text('Apply'),
      ),
    ],
  );
}
