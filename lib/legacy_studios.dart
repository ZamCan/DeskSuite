import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'business/inventory.dart';
import 'core/local_file_store.dart';
import 'core/atomic_file_store.dart' show recoverAtomicBackup;
import 'core/ids.dart';
import 'core/suite_paths.dart';
import 'images/photo_processor.dart';
import 'printing/print_gateway.dart';
import 'printing/design_export.dart' show effectiveImageDpi;
import 'printing/photo_sheet.dart';
import 'printing/photo_sheet_dialog.dart';
import 'workspace/file_gateway.dart';

const ink = Color(0xFF292B29);
const paper = Color(0xFFF7F5EF);
const accent = Color(0xFFB56B45);
const muted = Color(0xFF777970);

class LocalStore {
  static final LocalFileStore _files = LocalFileStore(suiteRoot);
  static Future<Directory> root() => suiteRoot();

  static Future<void> write(String name, String value) =>
      _files.writeText(name, value);
  static Future<String> read(String name, [String fallback = '']) =>
      _files.readText(name, fallback);
  static Future<void> saveProject(Project project) =>
      _files.writeEarlierProject(
        project.id,
        utf8.encode(jsonEncode(project.toJson())),
      );

  static Future<List<Project>> projects() async {
    await _files.waitForWrites();
    final dir = Directory(
      '${(await root()).path}${Platform.pathSeparator}projects',
    );
    if (!await dir.exists()) return [];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is File && entity.path.endsWith('.dsproject.bak')) {
        await recoverAtomicBackup(
          File(entity.path.substring(0, entity.path.length - 4)),
        );
      }
    }
    final result = <Project>[];
    await for (final f in dir.list(followLinks: false)) {
      if (f is! File || !f.path.endsWith('.dsproject')) continue;
      try {
        if (await f.length() > 32 * 1024 * 1024) continue;
        final project = Project.fromJson(
          jsonDecode(await f.readAsString()) as Map<String, dynamic>,
        );
        if (isSafeId(project.id) &&
            f.uri.pathSegments.last == '${project.id}.dsproject') {
          result.add(project);
        }
      } catch (_) {
        // The new project browser reports unreadable files; never modify one here.
      }
    }
    result.sort((a, b) => b.updated.compareTo(a.updated));
    return result;
  }

  static Future<String?> export(String name, Uint8List bytes) =>
      FilePicker.saveFile(
        dialogTitle: 'Export from DeskSuite',
        fileName: name,
        bytes: bytes,
        mimeType: name.endsWith('.pdf')
            ? 'application/pdf'
            : name.endsWith('.txt')
            ? 'text/plain'
            : 'application/octet-stream',
      ).then((uri) => uri?.toString());
}

class Project {
  Project({
    String? id,
    this.name = 'Untitled design',
    this.width = 360,
    this.height = 480,
    List<Map<String, dynamic>>? items,
    DateTime? updated,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
       items = items ?? [],
       updated = updated ?? DateTime.now();
  final String id;
  String name;
  double width, height;
  List<Map<String, dynamic>> items;
  DateTime updated;
  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'id': id,
    'name': name,
    'width': width,
    'height': height,
    'updated': updated.toIso8601String(),
    'items': items,
  };
  factory Project.fromJson(Map<String, dynamic> j) => Project(
    id: j['id'] as String?,
    name: j['name'] as String? ?? 'Untitled design',
    width: (j['width'] as num?)?.toDouble() ?? 360,
    height: (j['height'] as num?)?.toDouble() ?? 480,
    updated: DateTime.tryParse(j['updated'] as String? ?? '') ?? DateTime.now(),
    items: (j['items'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(),
  );
  Project copy() => Project.fromJson(toJson());
}

class CreativePage extends StatelessWidget {
  const CreativePage({super.key, required this.onCreate, required this.onOpen});
  final VoidCallback onCreate;
  final ValueChanged<Project> onOpen;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(22),
    children: [
      const Text(
        'Creative Studio',
        style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      const Text(
        'Create editable layouts locally and export them as PDF.',
        style: TextStyle(color: muted),
      ),
      const SizedBox(height: 22),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.crop_portrait_outlined, size: 36, color: accent),
              const SizedBox(height: 12),
              const Text(
                'Blank design',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Add text, shapes and images. Move objects, duplicate or delete them, undo and redo changes, save the editable project, and export PDF.',
                style: TextStyle(color: muted, height: 1.5),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add),
                label: const Text('Create design'),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: () async {
          final list = await LocalStore.projects();
          if (!context.mounted) return;
          await showModalBottomSheet<void>(
            context: context,
            showDragHandle: true,
            builder: (ctx) => ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Saved projects',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                if (list.isEmpty) const Text('No saved projects yet.'),
                ...list.map(
                  (p) => ListTile(
                    title: Text(p.name),
                    subtitle: Text('Updated ${p.updated.toLocal()}'),
                    onTap: () {
                      Navigator.pop(ctx);
                      onOpen(p);
                    },
                  ),
                ),
              ],
            ),
          );
        },
        icon: const Icon(Icons.folder_open_outlined),
        label: const Text('Open saved project'),
      ),
    ],
  );
}

class EditorPage extends StatefulWidget {
  const EditorPage({super.key, required this.project});
  final Project project;
  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  late Project p;
  String? selected;
  final undoStack = <Project>[], redoStack = <Project>[];
  bool busy = false, dirty = false, allowPop = false, closing = false;
  int revision = 0;
  @override
  void initState() {
    super.initState();
    p = widget.project.copy();
  }

  void checkpoint() {
    dirty = true;
    revision++;
    undoStack.add(p.copy());
    if (undoStack.length > 40) undoStack.removeAt(0);
    redoStack.clear();
  }

  void undo() {
    if (undoStack.isEmpty) return;
    redoStack.add(p.copy());
    setState(() {
      dirty = true;
      revision++;
      p = undoStack.removeLast();
    });
  }

  void redo() {
    if (redoStack.isEmpty) return;
    undoStack.add(p.copy());
    setState(() {
      dirty = true;
      revision++;
      p = redoStack.removeLast();
    });
  }

  void note(String s) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  Future<void> add(String kind) async {
    var text = '';
    if (kind == 'text') {
      final c = TextEditingController(text: 'Your headline');
      final v = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Add text'),
          content: TextField(controller: c, autofocus: true),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: const Text('Add'),
            ),
          ],
        ),
      );
      if (v == null || v.isEmpty) return;
      text = v;
    }
    checkpoint();
    final e = <String, dynamic>{
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'kind': kind,
      'text': text,
      'x': 25.0 + (p.items.length * 11) % 100,
      'y': 30.0 + (p.items.length * 17) % 180,
      'w': kind == 'text' ? 250.0 : 110.0,
      'h': kind == 'text' ? 65.0 : 100.0,
      'color': kind == 'circle' ? 0xFFB56B45 : 0xFF292B29,
      'size': 24.0,
    };
    setState(() {
      p.items.add(e);
      selected = e['id'] as String;
    });
  }

  Future<void> addImage() async {
    try {
      final bytes = await NativeFileGateway().pickImage();
      if (bytes == null) return;
      await processPhotoInBackground(PhotoRequest(bytes, PhotoAction.inspect));
      if (!mounted) return;
      checkpoint();
      final element = <String, dynamic>{
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'kind': 'image',
        'text': 'Image',
        'x': 30.0,
        'y': 80.0,
        'w': 230.0,
        'h': 160.0,
        'color': 0xFF292B29,
        'size': 24.0,
        'imageData': base64Encode(bytes),
      };
      setState(() {
        p.items.add(element);
        selected = element['id'] as String;
      });
    } catch (error) {
      if (mounted) note('Could not add image: $error');
    }
  }

  Future<void> requestClose() async {
    if (closing || busy) return;
    closing = true;
    if (dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Unsaved earlier design'),
          content: const Text(
            'The earlier editor uses manual Save. Keep editing and save, or discard these changes.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard changes'),
            ),
          ],
        ),
      );
      if (discard != true) {
        closing = false;
        return;
      }
    }
    if (!mounted) return;
    setState(() => allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> save() async {
    setState(() => busy = true);
    try {
      p.updated = DateTime.now();
      final savedRevision = revision;
      await LocalStore.saveProject(p);
      if (mounted) {
        if (savedRevision == revision) setState(() => dirty = false);
        note('Project saved on this device.');
      }
    } catch (e) {
      if (mounted) note('Save failed: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> rename() async {
    final c = TextEditingController(text: p.name);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Design name'),
        content: TextField(controller: c),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    c.dispose();
    if (v != null && v.isNotEmpty && v != p.name && mounted) {
      checkpoint();
      setState(() => p.name = v);
    }
  }

  pw.Widget pdfItem(Map<String, dynamic> e) {
    final color = PdfColor.fromInt(e['color'] as int);
    if (e['kind'] == 'rect') return pw.Container(color: color);
    if (e['kind'] == 'circle') {
      return pw.Container(
        decoration: pw.BoxDecoration(color: color, shape: pw.BoxShape.circle),
      );
    }
    if (e['kind'] == 'image' && e['imageData'] != null) {
      try {
        return pw.Image(
          pw.MemoryImage(base64Decode(e['imageData'] as String)),
          fit: pw.BoxFit.contain,
        );
      } catch (_) {
        return pw.Text('[Image unavailable]');
      }
    }
    return pw.Text(
      e['text'] as String,
      style: pw.TextStyle(
        fontSize: (e['size'] as num).toDouble() * .75,
        color: color,
        fontWeight: pw.FontWeight.bold,
      ),
    );
  }

  Future<void> exportPdf({bool print = false}) async {
    setState(() => busy = true);
    try {
      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(
            p.width * .75,
            p.height * .75,
            marginAll: 0,
          ),
          build: (_) => pw.Container(
            color: PdfColors.white,
            child: pw.Stack(
              children: [
                for (final e in p.items)
                  pw.Positioned(
                    left: (e['x'] as num).toDouble() * .75,
                    top: (e['y'] as num).toDouble() * .75,
                    child: pw.SizedBox(
                      width: (e['w'] as num).toDouble() * .75,
                      height: (e['h'] as num).toDouble() * .75,
                      child: pdfItem(e),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      final bytes = await doc.save();
      if (print) {
        await Printing.layoutPdf(onLayout: (_) async => bytes);
      } else {
        final safe = p.name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
        final path = await LocalStore.export('$safe.pdf', bytes);
        if (path != null && mounted) note('PDF exported.');
      }
    } catch (e) {
      if (mounted) note('PDF export failed: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget tool(IconData i, String s, VoidCallback f) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: OutlinedButton.icon(
      onPressed: f,
      icon: Icon(i, size: 18),
      label: Text(s),
    ),
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: allowPop,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) requestClose();
    },
    child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back to workspace',
          onPressed: busy ? null : requestClose,
          icon: const Icon(Icons.arrow_back),
        ),
        title: GestureDetector(
          onTap: rename,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                p.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                dirty
                    ? 'Unsaved · manual save'
                    : 'Earlier editor · manual save',
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Undo',
            onPressed: undoStack.isEmpty ? null : undo,
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            tooltip: 'Redo',
            onPressed: redoStack.isEmpty ? null : redo,
            icon: const Icon(Icons.redo),
          ),
          IconButton(
            tooltip: 'Save earlier design',
            onPressed: busy ? null : save,
            icon: const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                tool(Icons.title, 'Text', () => add('text')),
                tool(Icons.rectangle_outlined, 'Shape', () => add('rect')),
                tool(Icons.circle_outlined, 'Circle', () => add('circle')),
                tool(Icons.image_outlined, 'Image', addImage),
                tool(
                  Icons.picture_as_pdf_outlined,
                  'Export PDF',
                  () => exportPdf(),
                ),
                tool(
                  Icons.print_outlined,
                  'Print',
                  () => exportPdf(print: true),
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                final scale = math
                    .min(
                      (c.maxWidth - 28) / p.width,
                      (c.maxHeight - 28) / p.height,
                    )
                    .clamp(.1, 2.0);
                return Center(
                  child: Container(
                    width: p.width * scale,
                    height: p.height * scale,
                    color: Colors.white,
                    child: Stack(
                      children: [
                        for (final e in p.items)
                          Positioned(
                            left: (e['x'] as num).toDouble() * scale,
                            top: (e['y'] as num).toDouble() * scale,
                            width: (e['w'] as num).toDouble() * scale,
                            height: (e['h'] as num).toDouble() * scale,
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => selected = e['id'] as String),
                              onPanStart: (_) {
                                checkpoint();
                                setState(() => selected = e['id'] as String);
                              },
                              onPanUpdate: (d) {
                                setState(() {
                                  e['x'] =
                                      ((e['x'] as num).toDouble() +
                                              d.delta.dx / scale)
                                          .clamp(
                                            0.0,
                                            math.max(
                                              0,
                                              p.width -
                                                  (e['w'] as num).toDouble(),
                                            ),
                                          );
                                  e['y'] =
                                      ((e['y'] as num).toDouble() +
                                              d.delta.dy / scale)
                                          .clamp(
                                            0.0,
                                            math.max(
                                              0,
                                              p.height -
                                                  (e['h'] as num).toDouble(),
                                            ),
                                          );
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  border: selected == e['id']
                                      ? Border.all(color: accent, width: 1.5)
                                      : null,
                                  color: e['kind'] == 'rect'
                                      ? Color(e['color'] as int)
                                      : Colors.transparent,
                                  shape: e['kind'] == 'circle'
                                      ? BoxShape.circle
                                      : BoxShape.rectangle,
                                ),
                                clipBehavior: Clip.hardEdge,
                                child: e['kind'] == 'text'
                                    ? Align(
                                        alignment: Alignment.topLeft,
                                        child: Text(
                                          e['text'] as String,
                                          style: TextStyle(
                                            fontSize:
                                                (e['size'] as num).toDouble() *
                                                scale,
                                            color: Color(e['color'] as int),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      )
                                    : e['kind'] == 'image' &&
                                          e['imageData'] != null
                                    ? Image.memory(
                                        base64Decode(e['imageData'] as String),
                                        fit: BoxFit.contain,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (selected != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () {
                    checkpoint();
                    setState(
                      () => p.items.removeWhere((e) => e['id'] == selected),
                    );
                    selected = null;
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                ),
                TextButton.icon(
                  onPressed: () {
                    final e = p.items
                        .where((e) => e['id'] == selected)
                        .firstOrNull;
                    if (e == null) return;
                    checkpoint();
                    final cp = Map<String, dynamic>.from(e);
                    cp['id'] = DateTime.now().microsecondsSinceEpoch.toString();
                    cp['x'] = ((e['x'] as num).toDouble() + 16).clamp(
                      0,
                      p.width - (e['w'] as num).toDouble(),
                    );
                    cp['y'] = ((e['y'] as num).toDouble() + 16).clamp(
                      0,
                      p.height - (e['h'] as num).toDouble(),
                    );
                    setState(() {
                      p.items.add(cp);
                      selected = cp['id'] as String;
                    });
                  },
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Duplicate'),
                ),
              ],
            ),
          if (busy) const LinearProgressIndicator(),
        ],
      ),
    ),
  );
}

class PhotoPage extends StatefulWidget {
  const PhotoPage({
    super.key,
    this.files,
    this.processor,
    this.printer,
    this.sheetGenerator,
  });
  final FileGateway? files;
  final Future<PhotoResult> Function(PhotoRequest)? processor;
  final PrintGateway? printer;
  final Future<Uint8List> Function(PhotoSheetRequest)? sheetGenerator;
  @override
  State<PhotoPage> createState() => _PhotoPageState();
}

class _PhotoPageState extends State<PhotoPage> {
  late final FileGateway files = widget.files ?? NativeFileGateway();
  late final Future<PhotoResult> Function(PhotoRequest) process =
      widget.processor ?? processPhotoInBackground;
  PhotoResult? photo;
  PhotoResult? original;
  PhotoResult? undoPhoto;
  bool busy = false;
  bool showingOriginal = false;
  bool isExample = false;
  bool isNoisyExample = false;

  void note(String value) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(value)));
    }
  }

  Future<bool> confirmReplace() async {
    if (photo == null) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Replace working image?'),
            content: const Text(
              'Export the working copy first if you want to keep it. Replacing it does not change the imported source file.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Replace'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> pick() async {
    if (busy || !await confirmReplace() || !mounted) return;
    setState(() => busy = true);
    try {
      final bytes = await files.pickImage();
      if (bytes == null) return;
      final result = await process(PhotoRequest(bytes, PhotoAction.inspect));
      if (mounted) {
        setState(() {
          photo = result;
          original = result;
          undoPhoto = null;
          showingOriginal = false;
          isExample = false;
          isNoisyExample = false;
        });
      }
    } catch (error) {
      note(
        error is FormatException
            ? error.message
            : 'Could not open image. Try a supported file.',
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> loadExample({bool noisy = false}) async {
    if (busy || !await confirmReplace() || !mounted) return;
    setState(() => busy = true);
    try {
      final data = await rootBundle.load(
        noisy
            ? 'assets/samples/noisy-garden.png'
            : 'assets/samples/practice-photo.jpg',
      );
      final result = await process(
        PhotoRequest(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          PhotoAction.inspect,
        ),
      );
      if (mounted) {
        setState(() {
          photo = result;
          original = result;
          undoPhoto = null;
          showingOriginal = false;
          isExample = !noisy;
          isNoisyExample = noisy;
        });
      }
    } catch (_) {
      note('Could not load the example image. Try again.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void undo() {
    if (undoPhoto == null || busy) return;
    setState(() {
      photo = undoPhoto;
      undoPhoto = null;
      showingOriginal = false;
    });
  }

  void reset() {
    if (original == null || photo == null || busy) return;
    setState(() {
      undoPhoto = photo;
      photo = original;
      showingOriginal = false;
    });
  }

  Future<void> apply(
    PhotoAction action, {
    int? width,
    int? height,
    bool keepAspect = true,
  }) async {
    final current = photo;
    if (current == null || busy) return;
    setState(() => busy = true);
    try {
      final result = await process(
        PhotoRequest(
          current.bytes,
          action,
          width: width,
          height: height,
          keepAspect: keepAspect,
        ),
      );
      if (mounted) {
        setState(() {
          undoPhoto = current;
          photo = result;
          showingOriginal = false;
        });
      }
    } catch (error) {
      note(
        error is FormatException ? error.message : 'Image processing failed. Your previous working copy is unchanged.',
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> resize() async {
    final current = photo;
    if (current == null) return;
    final size = await showDialog<_PhotoSize>(
      context: context,
      builder: (_) =>
          _ResizePhotoDialog(width: current.width, height: current.height),
    );
    if (size != null && mounted) {
      await apply(
        PhotoAction.resize,
        width: size.width,
        height: size.height,
        keepAspect: size.keepAspect,
      );
    }
  }

  Future<void> export(bool jpeg) async {
    final current = photo;
    if (current == null || busy) return;
    final quality = jpeg
        ? await showDialog<int>(
            context: context,
            builder: (_) => const _JpegQualityDialog(),
          )
        : 90;
    if (quality == null || !mounted) return;
    setState(() => busy = true);
    try {
      final output = await process(
        PhotoRequest(
          current.bytes,
          jpeg ? PhotoAction.jpeg : PhotoAction.png,
          quality: quality,
        ),
      );
      if (!mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Review ${jpeg ? 'JPEG' : 'PNG'} output'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.memory(
                  output.bytes,
                  height: 150,
                  fit: BoxFit.contain,
                  cacheWidth: math.min(output.width, 800),
                ),
                const SizedBox(height: 12),
                Text(
                  '${output.width} × ${output.height} pixels · ${output.bytes.length} bytes',
                ),
                if (original != null)
                  Text(
                    'Original: ${original!.width} × ${original!.height} pixels · ${original!.bytes.length} bytes',
                  ),
                const SizedBox(height: 8),
                const Text(
                  'Choose a new destination to keep your source file. The final size shown is measured after encoding.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('photo-save-copy'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save a copy'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
      final saved = await files.save(
        name: jpeg ? 'desksuite-photo.jpg' : 'desksuite-photo.png',
        bytes: output.bytes,
        mimeType: jpeg ? 'image/jpeg' : 'image/png',
      );
      if (saved) {
        note('Image exported. Verify the saved copy in an image viewer.');
      }
    } catch (error) {
      note(
        error is FormatException
            ? error.message
            : 'Could not export image. Try another destination.',
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> makeSheet() async {
    final current = photo;
    if (current == null || busy) return;
    final choice = await showDialog<PhotoSheetChoice>(
      context: context,
      builder: (_) => PhotoSheetDialog(photo: current),
    );
    if (choice == null || !mounted) return;
    final spec = choice.spec;
    final dpi = effectiveImageDpi(
      current.width,
      current.height,
      spec.photoWidthMm,
      spec.photoHeightMm,
    );
    if (dpi < 150) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Low-resolution photo'),
          content: Text(
            'The placed photo has approximately ${dpi.round()} dpi. The output may look soft when printed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }
    setState(() => busy = true);
    try {
      final png = await process(PhotoRequest(current.bytes, PhotoAction.png));
      final pdf =
          await (widget.sheetGenerator ?? generatePhotoSheetInBackground)(
            PhotoSheetRequest(png.bytes, spec),
          );
      if (choice.print) {
        final sent = await (widget.printer ?? const SystemPrintGateway())
            .printPdf(
              bytes: pdf,
              name: 'DeskSuite photo sheet',
              widthMm: spec.pageWidthMm,
              heightMm: spec.pageHeightMm,
            );
        if (sent) note('Print job sent to the system service.');
      } else {
        final saved = await files.save(
          name: 'desksuite-photo-sheet.pdf',
          bytes: pdf,
          mimeType: 'application/pdf',
        );
        if (saved) note('Photo sheet PDF exported.');
      }
    } catch (error) {
      note('Could not prepare photo sheet: $error');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(22),
    children: [
      const Text(
        'Photo Studio',
        style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      const Text(
        'Edit a local copy; choose a new destination when exporting to preserve your source.',
        style: TextStyle(color: muted),
      ),
      const SizedBox(height: 20),
      Container(
        constraints: const BoxConstraints(minHeight: 240),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: photo == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 42,
                        color: accent,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Bring in a photo',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        key: const Key('photo-choose'),
                        onPressed: busy ? null : pick,
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Choose image'),
                      ),
                      const SizedBox(height: 6),
                      TextButton.icon(
                        key: const Key('photo-example'),
                        onPressed: busy ? null : () => loadExample(),
                        icon: const Icon(Icons.school_outlined),
                        label: const Text('Try a sample image'),
                      ),
                      TextButton.icon(
                        key: const Key('photo-noisy-example'),
                        onPressed: busy ? null : () => loadExample(noisy: true),
                        icon: const Icon(Icons.auto_fix_high),
                        label: const Text('Try a noisy garden photo'),
                      ),
                    ],
                  ),
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  height: 300,
                  child: InteractiveViewer(
                    key: const Key('photo-zoom'),
                    maxScale: 6,
                    child: Center(
                      child: Image.memory(
                        (showingOriginal ? original! : photo!).bytes,
                        fit: BoxFit.contain,
                        cacheWidth: math.min(
                          (showingOriginal ? original! : photo!).width,
                          1600,
                        ),
                        errorBuilder: (_, _, _) =>
                            const Text('Image preview unavailable.'),
                      ),
                    ),
                  ),
                ),
              ),
      ),
      if (photo != null) ...[
        const SizedBox(height: 10),
        Text('${photo!.width} × ${photo!.height} px · working copy'),
        if (original != null)
          Text(
            'Original: ${original!.width} × ${original!.height} px · ${detectPhotoFormat(original!.bytes).name.toUpperCase()} · ${original!.bytes.length} bytes',
          ),
        if (showingOriginal)
          const Text(
            'Previewing original; edits and exports use the working copy.',
          ),
        if (isExample)
          const Text(
            'Example: try Resize, enter a width such as 512 px, review the result, then save a new copy.',
          ),
        if (isNoisyExample)
          const Text(
            'Synthetic garden with added black and white specks: reduce specks, pinch to zoom, then compare with the original.',
          ),
        const Text(
          'Pinch the preview to inspect details. Reducing isolated specks can soften fine details; it does not remove blur, scratches or every kind of noise.',
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              key: const Key('photo-choose-another'),
              onPressed: busy ? null : pick,
              icon: const Icon(Icons.upload_file),
              label: const Text('Choose another'),
            ),
            OutlinedButton.icon(
              key: const Key('photo-noisy-example'),
              onPressed: busy ? null : () => loadExample(noisy: true),
              icon: const Icon(Icons.school_outlined),
              label: const Text('Noisy garden example'),
            ),
            OutlinedButton(
              key: const Key('photo-compare'),
              onPressed: busy
                  ? null
                  : () => setState(() => showingOriginal = !showingOriginal),
              child: Text(
                showingOriginal ? 'Show working copy' : 'Compare original',
              ),
            ),
            OutlinedButton(
              key: const Key('photo-undo'),
              onPressed: busy || undoPhoto == null ? null : undo,
              child: const Text('Undo last edit'),
            ),
            OutlinedButton(
              key: const Key('photo-reset'),
              onPressed: busy ? null : reset,
              child: const Text('Reset'),
            ),
            OutlinedButton.icon(
              key: const Key('photo-rotate'),
              onPressed: busy ? null : () => apply(PhotoAction.rotate90),
              icon: const Icon(Icons.rotate_right),
              label: const Text('Rotate 90°'),
            ),
            OutlinedButton.icon(
              key: const Key('photo-flip'),
              onPressed: busy ? null : () => apply(PhotoAction.flipHorizontal),
              icon: const Icon(Icons.flip),
              label: const Text('Flip'),
            ),
            FilledButton.tonalIcon(
              key: const Key('photo-denoise'),
              onPressed: busy
                  ? null
                  : () => apply(PhotoAction.reduceImpulseNoise),
              icon: const Icon(Icons.auto_fix_high),
              label: const Text('Reduce isolated specks'),
            ),
            OutlinedButton.icon(
              key: const Key('photo-resize'),
              onPressed: busy ? null : resize,
              icon: const Icon(Icons.photo_size_select_large),
              label: const Text('Resize'),
            ),
            OutlinedButton.icon(
              key: const Key('photo-crop'),
              onPressed: busy
                  ? null
                  : () => apply(PhotoAction.centerSquareCrop),
              icon: const Icon(Icons.crop_square),
              label: const Text('Centre square crop'),
            ),
            OutlinedButton.icon(
              key: const Key('photo-sheet'),
              onPressed: busy ? null : makeSheet,
              icon: const Icon(Icons.grid_view_outlined),
              label: const Text('Photo sheet'),
            ),
            FilledButton.icon(
              key: const Key('photo-jpg'),
              onPressed: busy ? null : () => export(true),
              icon: const Icon(Icons.save_alt),
              label: const Text('Export JPG'),
            ),
            OutlinedButton.icon(
              key: const Key('photo-png'),
              onPressed: busy ? null : () => export(false),
              icon: const Icon(Icons.save_alt),
              label: const Text('Export PNG'),
            ),
          ],
        ),
      ],
      if (busy)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: LinearProgressIndicator(),
        ),
      const SizedBox(height: 14),
      const InfoNote(
        text: 'PNG, JPEG and WebP input; first frame only. Import is limited to 8 MB and 12 megapixels. Speck reduction is limited to 4 megapixels and leaves transparent areas and image borders unchanged. The working copy is not restored after closing: export it to keep it. JPEG flattens transparency onto white. Photo sheets do not certify ID compliance.',
      ),
    ],
  );
}

class _PhotoSize {
  const _PhotoSize(this.width, this.height, this.keepAspect);
  final int width, height;
  final bool keepAspect;
}

class _ResizePhotoDialog extends StatefulWidget {
  const _ResizePhotoDialog({required this.width, required this.height});
  final int width, height;
  @override
  State<_ResizePhotoDialog> createState() => _ResizePhotoDialogState();
}

class _ResizePhotoDialogState extends State<_ResizePhotoDialog> {
  final form = GlobalKey<FormState>();
  late final TextEditingController width;
  late final TextEditingController height;
  bool keepAspect = true;

  @override
  void initState() {
    super.initState();
    final initialWidth = math.min(widget.width, 1600);
    width = TextEditingController(text: '$initialWidth');
    height = TextEditingController(
      text:
          '${math.max(1, (widget.height * initialWidth / widget.width).round())}',
    );
  }

  @override
  void dispose() {
    width.dispose();
    height.dispose();
    super.dispose();
  }

  String? validateSide(String? value) {
    final n = int.tryParse(value ?? '');
    return n == null || n < 1 || n > maxPhotoSide ? 'Use 1–8192 pixels' : null;
  }

  void updateHeight(String value) {
    final n = int.tryParse(value);
    if (keepAspect && n != null && n > 0) {
      height.text =
          '${math.max(1, (widget.height * n / widget.width).round())}';
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Resize image'),
    content: Form(
      key: form,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              key: const Key('photo-width'),
              controller: width,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Width (pixels)'),
              validator: validateSide,
              onChanged: updateHeight,
            ),
            TextFormField(
              key: const Key('photo-height'),
              controller: height,
              enabled: !keepAspect,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Height (pixels)'),
              validator: validateSide,
              onChanged: (_) => setState(() {}),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Keep aspect ratio'),
              value: keepAspect,
              onChanged: (value) {
                setState(() => keepAspect = value ?? true);
                if (keepAspect) updateHeight(width.text);
              },
            ),
            const Text(
              'Keep aspect ratio preserves proportions. Turn it off to force exact width and height, which may distort the image. Output is limited to 12 megapixels.',
            ),
            if ((int.tryParse(width.text) ?? 0) > widget.width ||
                (int.tryParse(height.text) ?? 0) > widget.height)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Enlargement adds interpolated pixels, not new detail.',
                ),
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
      FilledButton(
        onPressed: () {
          if (!form.currentState!.validate()) return;
          final w = int.parse(width.text), h = int.parse(height.text);
          if (w * h > maxPhotoPixels) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Output exceeds 12 megapixels.')),
            );
            return;
          }
          Navigator.pop(context, _PhotoSize(w, h, keepAspect));
        },
        child: const Text('Resize'),
      ),
    ],
  );
}

class _JpegQualityDialog extends StatefulWidget {
  const _JpegQualityDialog();
  @override
  State<_JpegQualityDialog> createState() => _JpegQualityDialogState();
}

class _JpegQualityDialogState extends State<_JpegQualityDialog> {
  double quality = 90;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('JPEG quality'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Quality ${quality.round()}'),
        Slider(
          key: const Key('photo-quality'),
          value: quality,
          min: 30,
          max: 100,
          divisions: 70,
          label: '${quality.round()}',
          onChanged: (value) => setState(() => quality = value),
        ),
        const Text('Transparent areas will become white.'),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, quality.round()),
        child: const Text('Export JPG'),
      ),
    ],
  );
}

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});
  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> with WidgetsBindingObserver {
  final c = TextEditingController();
  Timer? _debounce;
  Future<void>? _saveTask;
  bool loaded = false, saving = false, dirty = false;
  int revision = 0;
  String? loadError, saveError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    c.addListener(_changed);
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await LocalStore.read('notes.txt');
      if (!mounted) return;
      c.text = value; // Listener ignores the initial value while loading.
      setState(() {
        loaded = true;
        dirty = false;
        loadError = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          loaded = false;
          loadError = '$error';
        });
      }
    }
  }

  void _changed() {
    if (!loaded) return;
    revision++;
    dirty = true;
    saveError = null;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      unawaited(_flush());
    });
    if (mounted) setState(() {});
  }

  Future<void> _flush() {
    _debounce?.cancel();
    if (_saveTask != null) return _saveTask!;
    if (!loaded || !dirty) return Future.value();
    final task = _save();
    _saveTask = task;
    task.whenComplete(() => _saveTask = null);
    return task;
  }

  Future<void> _save() async {
    if (mounted) {
      setState(() {
        saving = true;
        saveError = null;
      });
    }
    try {
      while (dirty && mounted) {
        final snapshot = c.text;
        final currentRevision = revision;
        try {
          await LocalStore.write('notes.txt', snapshot);
        } catch (error) {
          saveError = '$error';
          break;
        }
        if (currentRevision == revision) dirty = false;
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      unawaited(_flush());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    if (loaded && dirty) {
      // Best effort on disposal; normal navigation keeps this page mounted.
      unawaited(
        LocalStore.write('notes.txt', c.text).catchError((Object _) {}),
      );
    }
    c.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    try {
      final path = await LocalStore.export(
        'desksuite-notes.txt',
        Uint8List.fromList(utf8.encode(c.text)),
      );
      if (path != null && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Notes exported.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not export notes: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Office Notes',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text(
          'A simple notebook saved locally.',
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: 12),
        Text(
          loadError != null
              ? 'Could not load notes; the original file was not changed.'
              : !loaded
              ? 'Loading…'
              : saving
              ? 'Saving locally…'
              : dirty
              ? 'Changes are not saved'
              : 'Saved on this device',
          style: TextStyle(
            color: (loadError != null || saveError != null)
                ? Theme.of(context).colorScheme.error
                : muted,
            fontSize: 12,
          ),
        ),
        if (loadError != null)
          TextButton(onPressed: _load, child: const Text('Retry loading')),
        if (saveError != null)
          TextButton(onPressed: _flush, child: const Text('Retry saving')),
        const SizedBox(height: 8),
        Expanded(
          child: TextField(
            key: const Key('notes-editor'),
            controller: c,
            enabled: loaded,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            decoration: const InputDecoration(
              hintText: 'Start writing…',
              contentPadding: EdgeInsets.all(16),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: loaded ? _export : null,
              icon: const Icon(Icons.file_download_outlined),
              label: const Text('Export TXT'),
            ),
            Text(
              '${c.text.length} characters',
              style: const TextStyle(color: muted, fontSize: 12),
            ),
          ],
        ),
      ],
    ),
  );
}

class PrintPage extends StatelessWidget {
  const PrintPage({super.key, this.printer});
  final PrintGateway? printer;
  Future<void> printTest(BuildContext context) async {
    final d = pw.Document();
    d.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(42),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'DeskSuite Print Check',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.Text('A4 - 210 x 297 mm'),
            pw.SizedBox(height: 20),
            pw.Text('Use this sheet to check page scale and printer margins.'),
            pw.SizedBox(height: 18),
            pw.Container(
              width: 100 * PdfPageFormat.mm,
              height: 1,
              color: PdfColors.black,
            ),
            pw.SizedBox(height: 6),
            pw.Text('The line above should measure 100 mm on paper.'),
            pw.Spacer(),
            pw.Text(
              'Generated locally by DeskSuite',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ],
        ),
      ),
    );
    try {
      final bytes = await d.save();
      await (printer ?? const SystemPrintGateway()).printPdf(
        bytes: bytes,
        name: 'DeskSuite A4 print check',
        widthMm: 210,
        heightMm: 297,
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open the print service: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(22),
    children: [
      const Text(
        'Print Studio',
        style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      const Text(
        'Generate local PDFs and print through supported system services.',
        style: TextStyle(color: muted),
      ),
      const SizedBox(height: 22),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.picture_as_pdf_outlined,
                size: 34,
                color: accent,
              ),
              const SizedBox(height: 12),
              const Text(
                'A4 print check',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Create an A4 PDF and open the system print dialog.',
                style: TextStyle(color: muted),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => printTest(context),
                icon: const Icon(Icons.print_outlined),
                label: const Text('Preview / print A4'),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      const InfoNote(
        text: 'Advanced bleed, colour management, imposition and production queues are not implemented yet.',
      ),
    ],
  );
}

class BusinessPage extends StatefulWidget {
  const BusinessPage({super.key, this.repository, this.files});
  final InventoryRepository? repository;
  final FileGateway? files;
  @override
  State<BusinessPage> createState() => _BusinessPageState();
}

class _BusinessPageState extends State<BusinessPage> {
  late final InventoryRepository repository =
      widget.repository ?? InventoryRepository(LocalStore._files);
  InventorySnapshot? snapshot;
  String? loadError;
  bool loading = true, busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final current = await repository.load();
      if (mounted) {
        setState(() {
          snapshot = current;
          loadError = null;
          loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          snapshot = null;
          loadError = '$error';
          loading = false;
        });
      }
    }
  }

  void note(String value) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(value)));
    }
  }

  Future<void> addProduct() async {
    final draft = await showDialog<_ProductDraft>(
      context: context,
      builder: (_) => const _AddProductDialog(),
    );
    if (draft == null || !mounted) return;
    setState(() => busy = true);
    try {
      final next = await repository.addProduct(
        name: draft.name,
        priceMinor: draft.priceMinor,
        stock: draft.stock,
      );
      if (mounted) setState(() => snapshot = next);
    } catch (error) {
      note('Could not save product. No change was made: $error');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> exportCatalogue() async {
    final current = snapshot;
    if (current == null || busy) return;
    setState(() => busy = true);
    try {
      final saved = await (widget.files ?? NativeFileGateway()).save(
        name: 'desksuite-products.json',
        bytes: Uint8List.fromList(utf8.encode(current.encodeJson())),
        mimeType: 'application/json',
      );
      if (saved) note('Catalogue copy exported.');
    } catch (error) {
      note('Could not export catalogue: $error');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> sell(InventoryProduct item) async {
    setState(() => busy = true);
    try {
      final next = await repository.recordOneUnit(item.id);
      if (mounted) setState(() => snapshot = next);
      note('One unit recorded as sold. Payments and receipts are not tracked.');
    } catch (error) {
      note('Could not update stock. No change was made: $error');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = snapshot;
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        const Text(
          'Business & POS',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text(
          'Local catalogue and basic stock counter.',
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: 18),
        if (loading)
          const LinearProgressIndicator()
        else if (loadError != null) ...[
          const Text(
            'Could not read the catalogue. Its original file has not been changed.',
          ),
          Text(loadError!),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () {
                setState(() => loading = true);
                _load();
              },
              child: const Text('Retry loading'),
            ),
          ),
        ] else if (current != null) ...[
          Row(
            children: [
              Expanded(
                child: Metric(
                  label: 'Products',
                  value: current.products.length.toString(),
                  icon: Icons.inventory_2_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Metric(
                  label: 'Units sold',
                  value: current.unitsSold.toString(),
                  icon: Icons.shopping_bag_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Metric(
            label: 'Stock value at listed prices',
            value: 'TZS ${formatMinorAmount(current.stockValueMinor)}',
            icon: Icons.payments_outlined,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Product catalogue',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
              FilledButton.icon(
                key: const Key('add-product'),
                onPressed: busy ? null : addProduct,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add product'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const Key('export-catalogue'),
              onPressed: busy ? null : exportCatalogue,
              icon: const Icon(Icons.file_download_outlined),
              label: const Text('Export catalogue JSON'),
            ),
          ),
          const SizedBox(height: 8),
          if (busy) const LinearProgressIndicator(),
          if (current.products.isEmpty)
            const EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'No products yet',
              detail: 'Add a product to start a local catalogue.',
            )
          else
            ...current.products.map(
              (product) => Card(
                child: ListTile(
                  key: ValueKey('product-${product.id}'),
                  leading: const Icon(
                    Icons.inventory_2_outlined,
                    color: accent,
                  ),
                  title: Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    'TZS ${formatMinorAmount(BigInt.from(product.priceMinor))} · Stock: ${product.stock}',
                  ),
                  trailing: IconButton(
                    tooltip: 'Record one unit sold',
                    onPressed: !busy && product.stock > 0
                        ? () => sell(product)
                        : null,
                    icon: const Icon(Icons.point_of_sale_outlined),
                  ),
                ),
              ),
            ),
        ],
        const SizedBox(height: 14),
        const InfoNote(
          text: 'Starter only: unit counts are stored locally. Payments, refunds, suppliers, receipts, profit reports and transaction-safe accounting are not implemented.',
        ),
      ],
    );
  }
}

class _ProductDraft {
  const _ProductDraft(this.name, this.priceMinor, this.stock);
  final String name;
  final int priceMinor;
  final int stock;
}

class _AddProductDialog extends StatefulWidget {
  const _AddProductDialog();
  @override
  State<_AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<_AddProductDialog> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final price = TextEditingController();
  final stock = TextEditingController(text: '1');

  @override
  void dispose() {
    name.dispose();
    price.dispose();
    stock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add product'),
    content: Form(
      key: form,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              key: const Key('product-name'),
              controller: name,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'Product name'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Enter a product name' : null,
            ),
            TextFormField(
              key: const Key('product-price'),
              controller: price,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Unit price (TZS)'),
              validator: (v) {
                try {
                  parseMinorAmount(v ?? '');
                  return null;
                } on FormatException catch (error) {
                  return error.message;
                }
              },
            ),
            TextFormField(
              key: const Key('product-stock'),
              controller: stock,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Opening stock'),
              validator: (v) {
                final value = int.tryParse(v ?? '');
                return value == null || value < 0 || value > maxStockCount
                    ? 'Enter a valid stock quantity'
                    : null;
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
      FilledButton(
        onPressed: () {
          if (form.currentState!.validate()) {
            Navigator.pop(
              context,
              _ProductDraft(
                name.text.trim(),
                parseMinorAmount(price.text),
                int.parse(stock.text),
              ),
            );
          }
        },
        child: const Text('Add'),
      ),
    ],
  );
}

class Metric extends StatelessWidget {
  const Metric({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent),
          const SizedBox(height: 10),
          Tooltip(
            message: value,
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: muted, fontSize: 12)),
        ],
      ),
    ),
  );
}

class InfoNote extends StatelessWidget {
  const InfoNote({super.key, required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFF0EAE0),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, color: accent, size: 19),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: ink, fontSize: 12, height: 1.5),
          ),
        ),
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
  });
  final IconData icon;
  final String title;
  final String detail;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 26),
    child: Column(
      children: [
        Icon(icon, size: 34, color: muted),
        const SizedBox(height: 10),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(
          detail,
          textAlign: TextAlign.center,
          style: const TextStyle(color: muted, height: 1.4),
        ),
      ],
    ),
  );
}
