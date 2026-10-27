import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';

import '../core/ids.dart';
import '../documents/stamp_signature_tools.dart';
import '../printing/design_export.dart';
import '../workspace/file_gateway.dart';
import '../workspace/project_repository.dart';
import 'design_controller.dart';
import 'design_document.dart';
import 'design_renderer.dart';
import 'editor_widgets.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({
    super.key,
    required this.document,
    required this.repository,
    required this.files,
  });
  final DesignDocument document;
  final ProjectRepository repository;
  final FileGateway files;
  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late final DesignController _controller;
  final _images = DesignImageCache();
  final _view = TransformationController();
  Future<void> _imageSync = Future.value();
  Timer? _debounce;
  DesignDocument? _pending;
  Future<bool>? _saveTask;
  bool _dirty = false;
  bool _saving = false;
  bool _busy = true;
  bool _allowPop = false;
  bool _closing = false;
  String? _saveError;
  String? _imageError;

  @override
  void initState() {
    super.initState();
    _controller = DesignController(widget.document, onChanged: _changed);
    _imageSync = _loadImages();
  }

  Future<void> _loadImages() async {
    try {
      await _images.sync(_controller.document);
      if (mounted) {
        setState(() {
          _imageError = null;
          _busy = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _imageError = '$error';
          _busy = false;
        });
      }
    }
  }

  void _changed(DesignDocument doc) {
    _pending = doc;
    _dirty = true;
    _saveError = null;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), () {
      unawaited(_flush());
    });
    _imageSync = _imageSync.then((_) async {
      try {
        await _images.sync(_controller.document);
        if (mounted) setState(() => _imageError = null);
      } catch (error) {
        if (mounted) setState(() => _imageError = '$error');
      }
    });
    if (mounted) setState(() {});
  }

  Future<bool> _flush() {
    _debounce?.cancel();
    if (_saveTask != null) return _saveTask!;
    final task = _performSave();
    _saveTask = task;
    task.whenComplete(() => _saveTask = null);
    return task;
  }

  Future<bool> _performSave() async {
    if (_pending == null) return _saveError == null;
    if (mounted) setState(() => _saving = true);
    try {
      while (_pending != null) {
        final snapshot = _pending!;
        _pending = null;
        try {
          await widget.repository.save(snapshot);
        } catch (error) {
          _pending ??= snapshot;
          _saveError = '$error';
          return false;
        }
      }
      _dirty = false;
      _saveError = null;
      return true;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _requestClose() async {
    if (_closing || _busy) return;
    _closing = true;
    final saved = await _flush();
    if (!mounted) return;
    if (!saved) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Changes could not be saved'),
          content: Text(
            '$_saveError\n\nStay and try again, or leave and discard unsaved changes. You can also export a project copy.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Stay'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard & leave'),
            ),
          ],
        ),
      );
      if (discard != true) {
        _closing = false;
        return;
      }
    }
    if (!mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _view.dispose();
    unawaited(_imageSync.whenComplete(_images.dispose));
    super.dispose();
  }

  void _message(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _addText() {
    final d = _controller.document;
    try {
      _controller.add(
        DesignElement(
          id: newId(),
          kind: ElementKind.text,
          x: d.widthMm * .1,
          y: d.heightMm * .1,
          width: d.widthMm * .75,
          height: d.heightMm * .2,
          text: 'Your text',
          fontSizePt: 28,
          bold: true,
        ),
      );
    } catch (error) {
      _message('$error');
    }
  }

  void _addShape(ElementKind kind) {
    final d = _controller.document;
    try {
      _controller.add(
        DesignElement(
          id: newId(),
          kind: kind,
          x: d.widthMm * .15,
          y: d.heightMm * .18,
          width: math.max(5, d.widthMm * .45),
          height: math.max(5, d.heightMm * .2),
          color: 0xffbd694f,
        ),
      );
    } catch (error) {
      _message('$error');
    }
  }

  Future<void> _chooseShape() async {
    final kind = await showModalBottomSheet<ElementKind>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Add a shape',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.rectangle_outlined),
              title: const Text('Rectangle'),
              onTap: () => Navigator.pop(context, ElementKind.rectangle),
            ),
            ListTile(
              leading: const Icon(Icons.circle_outlined),
              title: const Text('Ellipse'),
              onTap: () => Navigator.pop(context, ElementKind.ellipse),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
    if (kind != null) _addShape(kind);
  }

  Future<void> _addImage() async {
    try {
      final bytes = await widget.files.pickImage();
      if (bytes == null || !mounted) return;
      setState(() => _busy = true);
      final d = _controller.document;
      final id = newId();
      final provisional = DesignElement(
        id: id,
        kind: ElementKind.image,
        x: d.widthMm * .1,
        y: d.heightMm * .1,
        width: math.max(5, d.widthMm * .6),
        height: math.max(5, d.heightMm * .45),
        imageBytes: bytes,
      );
      await _imageSync;
      await _images.sync(d.copyWith(elements: [...d.elements, provisional]));
      final image = _images.images[id]!;
      final maxWidth = d.widthMm * .6;
      final maxHeight = d.heightMm * .45;
      final scale = math.min(maxWidth / image.width, maxHeight / image.height);
      _controller.add(
        provisional.copyWith(
          width: math.max(5, image.width * scale),
          height: math.max(5, image.height * scale),
        ),
      );
    } catch (error) {
      _message('Could not import image: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addStamp() async {
    final spec = await showStampDialog(context);
    if (spec == null || !mounted) return;
    final d = _controller.document;
    try {
      final stampWidth = switch (spec.placement) {
        StampPlacement.topCenter || StampPlacement.bottomCenter => d.widthMm * .8,
        _ => d.widthMm * .44,
      };
      final stampX = switch (spec.placement) {
        StampPlacement.topLeft || StampPlacement.bottomLeft => d.widthMm * .06,
        StampPlacement.topCenter || StampPlacement.bottomCenter =>
          (d.widthMm - stampWidth) / 2,
        StampPlacement.topRight || StampPlacement.bottomRight =>
          d.widthMm - stampWidth - d.widthMm * .06,
      };
      final stampHeight = d.heightMm * (spec.includeDate ? .16 : .1);
      final stampY = switch (spec.placement) {
        StampPlacement.topLeft ||
        StampPlacement.topCenter ||
        StampPlacement.topRight => d.heightMm * .08,
        StampPlacement.bottomLeft ||
        StampPlacement.bottomCenter ||
        StampPlacement.bottomRight => d.heightMm - stampHeight - d.heightMm * .08,
      };
      _controller.add(
        DesignElement(
          id: newId(),
          kind: ElementKind.text,
          x: stampX,
          y: stampY,
          width: stampWidth,
          height: stampHeight,
          text: spec.textAt(DateTime.now()),
          fontSizePt: spec.includeDate ? 17 : 21,
          bold: true,
          color: spec.color.toARGB32(),
          textAlignment: TextAlignment.center,
        ),
      );
      _message('Stamp added as an editable layer. Move it into position.');
    } catch (error) {
      _message('Could not add stamp: $error');
    }
  }

  Future<void> _addSignature() async {
    final png = await showSignatureCaptureDialog(context);
    if (png == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final d = _controller.document;
      final id = newId();
      final provisional = DesignElement(
        id: id,
        kind: ElementKind.image,
        x: d.widthMm * .1,
        y: d.heightMm * .72,
        width: d.widthMm * .55,
        height: d.heightMm * .16,
        imageBytes: png,
      );
      await _imageSync;
      await _images.sync(d.copyWith(elements: [...d.elements, provisional]));
      final image = _images.images[id]!;
      final maxWidth = d.widthMm * .55;
      final maxHeight = d.heightMm * .16;
      final scale = math.min(maxWidth / image.width, maxHeight / image.height);
      final width = image.width * scale;
      final height = image.height * scale;
      _controller.add(
        provisional.copyWith(
          x: d.widthMm * .1,
          y: math.max(0, d.heightMm - height - d.heightMm * .08),
          width: width,
          height: height,
        ),
      );
      _message('Signature added as an editable image layer.');
    } catch (error) {
      _message('Could not add signature: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editText() async {
    final selected = _controller.selected;
    if (selected == null || selected.kind != ElementKind.text) return;
    final value = await showDialog<String>(
      context: context,
      builder: (_) => EditTextDialog(initialText: selected.text),
    );
    if (value != null && _controller.selectedId == selected.id) {
      try {
        _controller.updateSelected((e) => e.copyWith(text: value));
      } catch (error) {
        _message('$error');
      }
    }
  }

  Future<void> _deleteSelected() async {
    if (_controller.selected == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this object?'),
        content: const Text(
          'You can restore it using Undo while the editor is open.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) _controller.deleteSelected();
  }

  void _inspect() {
    if (_controller.selected == null) {
      _message('Select an object on the canvas first.');
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => ObjectInspector(
        controller: _controller,
        onEditText: _editText,
        onDelete: () async {
          Navigator.pop(context);
          await _deleteSelected();
        },
      ),
    );
  }

  void _showLayers() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final elements = _controller.document.elements.reversed.toList();
          return SafeArea(
            child: SizedBox(
              height: math.min(460, 140.0 + elements.length * 60),
              child: Column(
                children: [
                  const ListTile(
                    title: Text(
                      'Layers',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text('Top of the list appears in front.'),
                  ),
                  Expanded(
                    child: elements.isEmpty
                        ? const Center(
                            child: Text('Add an object to start your design.'),
                          )
                        : ListView.builder(
                            itemCount: elements.length,
                            itemBuilder: (context, index) {
                              final e = elements[index];
                              final title = e.kind == ElementKind.text
                                  ? (e.text.isEmpty
                                        ? 'Empty text'
                                        : e.text.replaceAll('\n', ' '))
                                  : e.kind.name;
                              return ListTile(
                                selected: e.id == _controller.selectedId,
                                leading: Icon(switch (e.kind) {
                                  ElementKind.text => Icons.title,
                                  ElementKind.rectangle =>
                                    Icons.rectangle_outlined,
                                  ElementKind.ellipse => Icons.circle_outlined,
                                  ElementKind.image => Icons.image_outlined,
                                }),
                                title: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () {
                                  _controller.select(e.id);
                                  Navigator.pop(context);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _export() async {
    final choice = await showModalBottomSheet<_ExportChoice>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text(
                  'Export',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text('Choose a file to save outside DeskSuite.'),
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: const Text('Print-ready PDF · 150 dpi'),
                subtitle: const Text('Single page, raster artwork'),
                onTap: () => Navigator.pop(context, _ExportChoice.pdf150),
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: const Text('Print-ready PDF · 300 dpi'),
                subtitle: const Text('Higher resolution; larger file'),
                onTap: () => Navigator.pop(context, _ExportChoice.pdf300),
              ),
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: const Text('PNG image · 150 dpi'),
                onTap: () => Navigator.pop(context, _ExportChoice.png150),
              ),
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: const Text('PNG image · 300 dpi'),
                onTap: () => Navigator.pop(context, _ExportChoice.png300),
              ),
              ListTile(
                leading: const Icon(Icons.save_outlined),
                title: const Text('Editable project copy'),
                subtitle: const Text('Use this to back up or move your design'),
                onTap: () => Navigator.pop(context, _ExportChoice.project),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice != _ExportChoice.project && !await _flush()) {
      _message(
        'Local save failed. Export an editable project copy to protect your work.',
      );
      return;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await _imageSync;
      if (_imageError != null && choice != _ExportChoice.project) {
        throw StateError('An image could not be decoded: $_imageError');
      }
      final doc = _controller.document;
      if (choice != _ExportChoice.project) {
        final dpi =
            choice == _ExportChoice.pdf150 || choice == _ExportChoice.png150
            ? 150
            : 300;
        final lowest = lowestPlacedImageDpi(doc, _images.images);
        if (lowest != null && lowest < dpi) {
          if (!mounted) return;
          final proceed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Low-resolution image'),
              content: Text(
                'An image has approximately ${lowest.toStringAsFixed(0)} dpi at its current size. '
                'The export is $dpi dpi; increasing export resolution cannot add image detail.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Export anyway'),
                ),
              ],
            ),
          );
          if (proceed != true) return;
        }
      }
      late Uint8List bytes;
      late String extension;
      late String mime;
      switch (choice) {
        case _ExportChoice.project:
          bytes = doc.encode();
          extension = 'dsdesign';
          mime = 'application/octet-stream';
        case _ExportChoice.png150:
        case _ExportChoice.png300:
          bytes = await renderPng(
            doc,
            _images.images,
            dpi: choice == _ExportChoice.png150 ? 150 : 300,
          );
          extension = 'png';
          mime = 'image/png';
        case _ExportChoice.pdf150:
        case _ExportChoice.pdf300:
          bytes = await renderPdf(
            doc,
            _images.images,
            dpi: choice == _ExportChoice.pdf150 ? 150 : 300,
          );
          extension = 'pdf';
          mime = 'application/pdf';
      }
      final name = doc.name.trim().replaceAll(RegExp(r'[^a-zA-Z0-9 _-]'), '_');
      final saved = await widget.files.save(
        name: '${name.isEmpty ? 'design' : name}.$extension',
        bytes: bytes,
        mimeType: mime,
      );
      if (saved) _message('Export saved.');
    } catch (error) {
      _message('Export failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _zoom(double factor) {
    final scale = (_view.value.getMaxScaleOnAxis() * factor).clamp(.75, 4.0);
    _view.value = Matrix4.diagonal3Values(scale, scale, 1);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _requestClose();
    },
    child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back to workspace',
          onPressed: _requestClose,
          icon: const Icon(Icons.arrow_back),
        ),
        titleSpacing: 0,
        title: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _controller.document.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                _saveError != null
                    ? 'Save failed · tap retry below'
                    : _saving
                    ? 'Saving…'
                    : _dirty
                    ? 'Unsaved changes'
                    : 'Saved locally',
                style: TextStyle(
                  fontSize: 11,
                  color: _saveError != null
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        actions: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => IconButton(
              tooltip: 'Undo',
              onPressed: !_busy && _controller.canUndo
                  ? _controller.undo
                  : null,
              icon: const Icon(Icons.undo),
            ),
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => IconButton(
              tooltip: 'Redo',
              onPressed: !_busy && _controller.canRedo
                  ? _controller.redo
                  : null,
              icon: const Icon(Icons.redo),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton.filled(
              tooltip: 'Export design',
              onPressed: _busy ? null : _export,
              icon: const Icon(Icons.ios_share_rounded),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_saveError != null)
            Material(
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                dense: true,
                title: const Text('Changes are not saved'),
                subtitle: Text(
                  _saveError!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: TextButton(
                  onPressed: _flush,
                  child: const Text('Retry'),
                ),
              ),
            ),
          if (_imageError != null)
            Material(
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.warning_amber_rounded),
                title: const Text('An image could not be decoded'),
                subtitle: const Text(
                  'The project is preserved; export is unavailable until the image is fixed.',
                ),
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: _canvas()),
                if (_busy)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Color(0x66000000),
                      child: Center(
                        child: Card(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 12),
                                Text('Preparing…'),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _toolbar(),
        ],
      ),
    ),
  );

  Widget _canvas() => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) {
        final d = _controller.document;
        final width = math.max(50.0, constraints.maxWidth - 48);
        final height = math.max(50.0, constraints.maxHeight - 48);
        final scale = math.min(width / d.widthMm, height / d.heightMm);
        final pageSize = Size(d.widthMm * scale, d.heightMm * scale);
        Offset toDocument(Offset p) => Offset(p.dx / scale, p.dy / scale);
        return ColoredBox(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xff302e2a)
              : const Color(0xffeae6df),
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  transformationController: _view,
                  minScale: .75,
                  maxScale: 4,
                  child: Center(
                    child: Container(
                      width: pageSize.width,
                      height: pageSize.height,
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: .13),
                            blurRadius: 20,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ClipRect(
                        child: GestureDetector(
                          key: const Key('design-canvas'),
                          behavior: HitTestBehavior.opaque,
                          dragStartBehavior: DragStartBehavior.down,
                          onTapDown: (details) {
                            _controller.beginGesture(
                              toDocument(details.localPosition),
                              handleRadiusMm: 12 / scale,
                            );
                            _controller.endGesture();
                          },
                          onDoubleTap: _editText,
                          onPanStart: (details) => _controller.beginGesture(
                            toDocument(details.localPosition),
                            handleRadiusMm: 12 / scale,
                          ),
                          onPanUpdate: (details) => _controller.updateGesture(
                            Offset(
                              details.delta.dx / scale,
                              details.delta.dy / scale,
                            ),
                          ),
                          onPanEnd: (_) => _controller.endGesture(),
                          onPanCancel: _controller.endGesture,
                          child: CustomPaint(
                            painter: DesignPainter(
                              d,
                              _images.images,
                              selectedId: _controller.selectedId,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 16,
                top: 14,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface
                        .withValues(alpha: .92),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Text(
                      '${d.widthMm.toStringAsFixed(0)} × ${d.heightMm.toStringAsFixed(0)} mm',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 12,
                bottom: 12,
                child: Card(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Zoom out',
                        onPressed: () => _zoom(1 / 1.25),
                        icon: const Icon(Icons.remove, size: 20),
                      ),
                      IconButton(
                        tooltip: 'Fit canvas',
                        onPressed: () => _view.value = Matrix4.identity(),
                        icon: const Icon(Icons.fit_screen_outlined, size: 20),
                      ),
                      IconButton(
                        tooltip: 'Zoom in',
                        onPressed: () => _zoom(1.25),
                        icon: const Icon(Icons.add, size: 20),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );

  Widget _toolbar() => Material(
    color: Theme.of(context).colorScheme.surface,
    child: SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 1),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _controller.selected == null
                          ? 'Tap an object to select it · drag to move'
                          : '${_controller.selected!.kind.name.toUpperCase()} SELECTED · drag the corner to resize',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        letterSpacing: .3,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (_controller.selected != null)
                    TextButton(
                      onPressed: _inspect,
                      child: const Text('Edit object'),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(
            height: 67,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                EditorToolButton(
                  key: const Key('add-text'),
                  icon: Icons.title_rounded,
                  label: 'Text',
                  onTap: _busy ? null : _addText,
                ),
                EditorToolButton(
                  icon: Icons.category_outlined,
                  label: 'Shape',
                  onTap: _busy ? null : _chooseShape,
                ),
                EditorToolButton(
                  key: const Key('add-image'),
                  icon: Icons.image_outlined,
                  label: 'Image',
                  onTap: _busy ? null : _addImage,
                ),
                EditorToolButton(
                  icon: Icons.verified_outlined,
                  label: 'Stamp',
                  onTap: _busy ? null : _addStamp,
                ),
                EditorToolButton(
                  icon: Icons.draw_outlined,
                  label: 'Signature',
                  onTap: _busy ? null : _addSignature,
                ),
                EditorToolButton(
                  icon: Icons.layers_outlined,
                  label: 'Layers',
                  onTap: _busy ? null : _showLayers,
                ),
                EditorToolButton(
                  icon: Icons.tune_rounded,
                  label: 'Edit',
                  onTap: _busy ? null : _inspect,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

enum _ExportChoice { pdf150, pdf300, png150, png300, project }
