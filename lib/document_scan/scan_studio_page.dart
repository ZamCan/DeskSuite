import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../core/suite_paths.dart';
import '../images/photo_processor.dart';
import '../ocr/text_extraction_page.dart';
import '../printing/paper_catalog.dart';
import '../workspace/file_gateway.dart';
import 'camera_gateway.dart';
import 'corner_editor.dart';
import 'document_cleanup.dart';
import 'document_cleanup_dialog.dart';
import 'scan_draft_store.dart';
import 'scan_pdf.dart';
import 'scan_processor.dart';

enum CorrectionAspect {
  estimated('Estimate', null),
  a4Portrait('A4 · portrait', 210 / 297),
  a4Landscape('A4 · landscape', 297 / 210),
  letterPortrait('Letter · portrait', 8.5 / 11),
  letterLandscape('Letter · landscape', 11 / 8.5);

  const CorrectionAspect(this.label, this.ratio);
  final String label;
  final double? ratio;
}

class ScanStudioPage extends StatefulWidget {
  const ScanStudioPage({
    super.key,
    required this.files,
    this.camera,
    this.recoveredCapture,
    this.storeFactory,
    this.photoProcessor,
    this.scanProcessor,
    this.cleanupProcessor,
    this.pdfGenerator,
    this.textExtractionBuilder,
  });
  final FileGateway files;
  final CameraGateway? camera;
  final Uint8List? recoveredCapture;
  final Future<ScanDraftStore> Function()? storeFactory;
  final Future<PhotoResult> Function(PhotoRequest)? photoProcessor;
  final Future<PhotoResult> Function(ScanRequest)? scanProcessor;
  final Future<PhotoResult> Function(DocumentCleanupRequest)? cleanupProcessor;
  final Future<Uint8List> Function(ScanPdfRequest)? pdfGenerator;

  /// Test seam; production opens the real offline text-extraction screen.
  final Widget Function(Uint8List pageBytes)? textExtractionBuilder;

  @override
  State<ScanStudioPage> createState() => _ScanStudioPageState();
}

class _ScanStudioPageState extends State<ScanStudioPage> {
  ScanDraftStore? store;
  List<ScanDraftPage> pages = [];
  int selected = 0;
  bool loading = true, busy = false;
  String? loadError, saveError;
  Uint8List? recovered;
  bool recoveryAdded = false;
  String? recoveryPageId;
  PhotoResult? undoImage;
  String? undoId;
  ScanPaper paper = ScanPaper.a4;
  int paperPresetIndex = 0;
  bool autoRotatePaper = true;
  final pageWidthController = TextEditingController(text: '210');
  final pageHeightController = TextEditingController(text: '297');
  CorrectionAspect correctionAspect = CorrectionAspect.estimated;

  Future<PhotoResult> Function(PhotoRequest) get processPhoto =>
      widget.photoProcessor ?? processPhotoInBackground;
  Future<PhotoResult> Function(ScanRequest) get processPage =>
      widget.scanProcessor ?? processScanInBackground;
  Future<PhotoResult> Function(DocumentCleanupRequest) get processCleanup =>
      widget.cleanupProcessor ?? processDocumentCleanupInBackground;

  @override
  void initState() {
    super.initState();
    recovered = widget.recoveredCapture;
    _load();
  }

  @override
  void dispose() {
    pageWidthController.dispose();
    pageHeightController.dispose();
    super.dispose();
  }

  void _selectPaperPreset(int? index) {
    if (index == null) return;
    setState(() {
      paperPresetIndex = index;
      if (index < paperSheetPresets.length) {
        final preset = paperSheetPresets[index];
        pageWidthController.text = preset.widthMm.toString();
        pageHeightController.text = preset.heightMm.toString();
        paper = preset.label.startsWith('US Letter')
            ? ScanPaper.letter
            : ScanPaper.a4;
      }
    });
  }

  @override
  void didUpdateWidget(covariant ScanStudioPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.recoveredCapture != null &&
        !identical(oldWidget.recoveredCapture, widget.recoveredCapture)) {
      recovered = widget.recoveredCapture;
    }
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      loadError = null;
    });
    try {
      final instance = await (widget.storeFactory?.call() ?? _defaultStore());
      final restored = await instance.load();
      if (!mounted) return;
      setState(() {
        store = instance;
        pages = restored;
        selected = 0;
        loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          loadError = 'The saved scan draft could not be opened. Retry or discard it after checking your backups.';
        });
      }
    }
  }

  Future<ScanDraftStore> _defaultStore() async {
    final root = await suiteRoot();
    return ScanDraftStore(
      Directory('${root.path}${Platform.pathSeparator}scan_draft'),
    );
  }

  void message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  String readableError(Object error, String fallback) =>
      error is FormatException ? error.message : fallback;

  Future<bool> _persist() async {
    try {
      final committed = await store!.save(List.of(pages));
      if (mounted) {
        setState(() {
          pages = committed;
          saveError = null;
          if (recoveryAdded &&
              committed.any((page) => page.id == recoveryPageId)) {
            recovered = null;
            recoveryAdded = false;
            recoveryPageId = null;
          }
        });
      }
      return true;
    } catch (_) {
      if (mounted) {
        setState(
          () => saveError = 'Draft could not be saved. Your current pages remain in memory: retry or export them before closing.',
        );
      }
      return false;
    }
  }

  void _checkCapacity(List<PhotoResult> additions, {int? replacing}) {
    var count = pages.length + additions.length - (replacing == null ? 0 : 1);
    var pixels = 0, bytes = 0;
    for (var i = 0; i < pages.length; i++) {
      if (i == replacing) continue;
      pixels += pages[i].image.width * pages[i].image.height;
      bytes += pages[i].image.bytes.length;
    }
    for (final image in additions) {
      pixels += image.width * image.height;
      bytes += image.bytes.length;
    }
    if (count > maxScanPages ||
        pixels > maxScanTotalPixels ||
        bytes > maxScanTotalBytes) {
      throw const FormatException(
        'A draft can contain up to 8 pages, 24 megapixels and 32 MB of processed images in total.',
      );
    }
  }

  Future<bool> _addBytes(Uint8List bytes, {bool fromRecovery = false}) async {
    if (pages.length >= maxScanPages) {
      throw const FormatException(
        'Remove a page before adding another; the limit is 8.',
      );
    }
    final image = await processPhoto(PhotoRequest(bytes, PhotoAction.png));
    _checkCapacity([image]);
    if (!mounted) return false;
    setState(() {
      pages = [...pages, ScanDraftPage(original: image, image: image)];
      selected = pages.length - 1;
      undoImage = null;
      undoId = null;
      if (fromRecovery) {
        recoveryAdded = true;
        recoveryPageId = pages.last.id;
      }
    });
    final saved = await _persist();
    if (fromRecovery && saved && mounted) {
      // Clear the recovery entry only after the draft manifest is committed.
      // This explicit post-save transition also avoids leaving camera actions
      // disabled if the store returns normalized page objects.
      setState(() {
        recovered = null;
        recoveryAdded = false;
        recoveryPageId = null;
      });
    }
    return saved;
  }

  Future<void> _import() async {
    if (busy || loading) return;
    setState(() => busy = true);
    try {
      final data = await widget.files.pickImage();
      if (data != null) await _addBytes(data);
    } catch (e) {
      message(
        readableError(
          e,
          'Could not import this image. Try another supported file.',
        ),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _capture() async {
    if (busy || loading || widget.camera == null || recovered != null) return;
    setState(() => busy = true);
    try {
      final data = await widget.camera!.capture();
      if (data != null && mounted) {
        // Retain the camera result if decoding, limits, or draft saving fail.
        setState(() => recovered = data);
        await _addBytes(data, fromRecovery: true);
      }
    } catch (e) {
      message(
        readableError(
          e,
          'Could not open the camera or read its result. Check the camera app and try again.',
        ),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _addRecovered() async {
    final data = recovered;
    if (data == null || busy || loading) return;
    setState(() => busy = true);
    try {
      await _addBytes(data, fromRecovery: true);
    } catch (e) {
      message(
        readableError(
          e,
          'Could not add the recovered capture. Save its original or try again.',
        ),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _saveRecovered() async {
    final data = recovered;
    if (data == null || busy) return;
    setState(() => busy = true);
    try {
      final format = detectPhotoFormat(data);
      final extension = switch (format) {
        PhotoFormat.png => 'png',
        PhotoFormat.jpeg => 'jpg',
        PhotoFormat.webp => 'webp',
      };
      final mime = switch (format) {
        PhotoFormat.png => 'image/png',
        PhotoFormat.jpeg => 'image/jpeg',
        PhotoFormat.webp => 'image/webp',
      };
      final saved = await widget.files.save(
        name: 'recovered-capture.$extension',
        bytes: data,
        mimeType: mime,
      );
      if (saved) {
        message(
          'Recovered original exported. It is still available here until added to the draft.',
        );
      }
    } catch (_) {
      message(
        'Could not export the recovered capture. Try another destination.',
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _dismissRecovered() async {
    if (busy || recovered == null || recoveryAdded) return;
    final confirmed = await _confirm(
      'Dismiss camera image?',
      'If you have not exported this image, it may be lost. This does not remove any file you already saved.',
      'Dismiss',
    );
    if (confirmed && mounted) setState(() => recovered = null);
  }

  Future<void> _samples() async {
    if (busy || loading) return;
    final paths = await showDialog<List<String>>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Choose a fictional example'),
        children: [
          SimpleDialogOption(
            key: const Key('sample-magic-page'),
            onPressed: () =>
                Navigator.pop(context, ['shadowed-practice-page.png']),
            child: const Text(
              'Shadowed practice report · compare enhancement modes',
            ),
          ),
          SimpleDialogOption(
            key: const Key('sample-angled-page'),
            onPressed: () =>
                Navigator.pop(context, ['angled-practice-page.jpg']),
            child: const Text(
              'Angled practice report · correct corners and clean',
            ),
          ),
          SimpleDialogOption(
            key: const Key('sample-clean-page'),
            onPressed: () =>
                Navigator.pop(context, ['clean-practice-page.png']),
            child: const Text('Clean practice report · reference page'),
          ),
          SimpleDialogOption(
            key: const Key('sample-cleanup'),
            onPressed: () =>
                Navigator.pop(context, ['shadowed-field-notes.png']),
            child: const Text(
              'Shadowed field notes · practise before/after cleanup',
            ),
          ),
          SimpleDialogOption(
            key: const Key('sample-perspective'),
            onPressed: () => Navigator.pop(context, ['perspective-letter.png']),
            child: const Text(
              'Perspective letter · practise corner correction',
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, ['letter.png']),
            child: const Text('Formal letter'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, ['invoice.png']),
            child: const Text('Example invoice'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, ['application-form.png']),
            child: const Text('Practice application form'),
          ),
          SimpleDialogOption(
            key: const Key('sample-report'),
            onPressed: () =>
                Navigator.pop(context, ['report-1.png', 'report-2.png']),
            child: const Text('Two-page report · practise a multipage PDF'),
          ),
          SimpleDialogOption(
            key: const Key('sample-office-pack'),
            onPressed: () => Navigator.pop(context, [
              'letter.png',
              'invoice.png',
              'application-form.png',
            ]),
            child: const Text(
              'Three-page office pack · letter, invoice and practice form',
            ),
          ),
          SimpleDialogOption(
            key: const Key('sample-cleanup-pack'),
            onPressed: () => Navigator.pop(context, [
              'clean-practice-page.png',
              'shadowed-practice-page.png',
              'angled-practice-page.jpg',
            ]),
            child: const Text(
              'Three-page scan pack · clean, shadowed and angled examples',
            ),
          ),
        ],
      ),
    );
    if (paths == null || !mounted) return;
    setState(() => busy = true);
    try {
      if (pages.length + paths.length > maxScanPages) {
        throw const FormatException(
          'This package would exceed the 8-page draft limit. Remove pages first.',
        );
      }
      final prepared = <PhotoResult>[];
      for (final path in paths) {
        final data = await rootBundle.load('assets/samples/$path');
        prepared.add(
          await processPhoto(
            PhotoRequest(
              data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
              PhotoAction.png,
            ),
          ),
        );
      }
      _checkCapacity(prepared);
      if (!mounted) return;
      setState(() {
        pages = [
          ...pages,
          for (final image in prepared)
            ScanDraftPage(original: image, image: image),
        ];
        selected = pages.length - prepared.length;
        undoImage = null;
        undoId = null;
      });
      final saved = await _persist();
      message(
        saved
            ? 'Example added. Adjust the pages or export the PDF using the same tools as your own files.'
            : 'Example added in memory, but the draft was not saved. Retry saving or export before closing.',
      );
    } catch (e) {
      message(readableError(e, 'Could not load the example. Try again.'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _edit(
    Future<PhotoResult> Function(PhotoResult) operation,
  ) async {
    if (busy || pages.isEmpty) return;
    final page = pages[selected];
    setState(() => busy = true);
    try {
      final image = await operation(page.image);
      _checkCapacity([image], replacing: selected);
      if (!mounted) return;
      setState(() {
        undoImage = page.image;
        undoId = page.id;
        pages = List.of(pages)..[selected] = page.withImage(image);
      });
      await _persist();
    } catch (e) {
      message(
        readableError(
          e,
          'Could not process this page. Your previous page is unchanged.',
        ),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _crop() async {
    if (busy || pages.isEmpty) return;
    final corners = await showDialog<ScanCorners>(
      context: context,
      builder: (_) => CornerEditor(photo: pages[selected].image),
    );
    if (corners != null && mounted) {
      await _edit(
        (image) => processPage(
          ScanRequest(
            image.bytes,
            corners: corners,
            outputAspect: correctionAspect.ratio,
          ),
        ),
      );
    }
  }

  Future<void> _cleanup() async {
    if (busy || pages.isEmpty) return;
    final page = pages[selected];
    final cleaned = await showDialog<PhotoResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          DocumentCleanupDialog(page: page.image, processor: processCleanup),
    );
    if (cleaned != null &&
        !identical(cleaned, page.image) &&
        mounted &&
        pages.isNotEmpty &&
        pages[selected].id == page.id) {
      await _edit((_) async => cleaned);
    }
  }

  Future<void> _openTextExtraction() async {
    if (busy || pages.isEmpty) return;
    final bytes = pages[selected].image.bytes;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Text extraction')),
          body:
              widget.textExtractionBuilder?.call(bytes) ??
              TextExtractionPage(files: widget.files, initialImage: bytes),
        ),
      ),
    );
  }

  Future<void> _undo() async {
    if (busy ||
        pages.isEmpty ||
        undoId != pages[selected].id ||
        undoImage == null) {
      return;
    }
    final previous = undoImage!;
    setState(() => busy = true);
    try {
      final page = pages[selected];
      setState(() {
        pages = List.of(pages)..[selected] = page.withImage(previous);
        undoImage = null;
        undoId = null;
      });
      await _persist();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _reset() async {
    if (busy || pages.isEmpty) return;
    final page = pages[selected];
    await _edit((_) async => page.original);
  }

  Future<void> _move(int direction) async {
    final target = selected + direction;
    if (busy || target < 0 || target >= pages.length) return;
    setState(() {
      busy = true;
      pages = List.of(pages);
      final page = pages.removeAt(selected);
      pages.insert(target, page);
      selected = target;
    });
    await _persist();
    if (mounted) setState(() => busy = false);
  }

  Future<bool> _confirm(String title, String detail, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(detail),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _remove() async {
    if (busy || pages.isEmpty) return;
    if (!await _confirm(
          'Remove this page?',
          'This removes the page from the saved scan draft, not the imported source file. This cannot be undone.',
          'Remove page',
        ) ||
        !mounted) {
      return;
    }
    setState(() {
      busy = true;
      if (pages[selected].id == recoveryPageId) {
        recoveryAdded = false;
        recoveryPageId = null;
      }
      pages = List.of(pages)..removeAt(selected);
      if (selected >= pages.length) {
        selected = pages.isEmpty ? 0 : pages.length - 1;
      }
      undoId = null;
      undoImage = null;
    });
    await _persist();
    if (mounted) setState(() => busy = false);
  }

  Future<void> _discard() async {
    if (busy) return;
    if (!await _confirm(
          'Discard scan draft?',
          'This permanently removes this app’s saved scan draft and its page copies. Imported files and exports are not deleted.',
          'Discard draft',
        ) ||
        !mounted) {
      return;
    }
    setState(() => busy = true);
    try {
      final instance =
          store ?? await (widget.storeFactory?.call() ?? _defaultStore());
      await instance.discard();
      if (!mounted) return;
      setState(() {
        store = instance;
        pages = [];
        selected = 0;
        loadError = null;
        saveError = null;
        undoId = null;
        undoImage = null;
        recoveryAdded = false;
        recoveryPageId = null;
      });
      message('Scan draft discarded.');
    } catch (_) {
      message('Could not discard the draft. Try again.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _exportPage() async {
    if (pages.isEmpty || busy) return;
    setState(() => busy = true);
    try {
      final saved = await widget.files.save(
        name: 'desksuite-page-${selected + 1}.png',
        bytes: pages[selected].image.bytes,
        mimeType: 'image/png',
      );
      if (saved) {
        message(
          'Page exported. Choose a separate destination to preserve the source.',
        );
      }
    } catch (_) {
      message('Could not export the page. Try another destination.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _pdf() async {
    if (pages.isEmpty || busy) return;
    final pageWidth = double.tryParse(pageWidthController.text);
    final pageHeight = double.tryParse(pageHeightController.text);
    if (pageWidth == null ||
        pageHeight == null ||
        !validPdfPageDimensions(pageWidth, pageHeight)) {
      message('Enter both page dimensions from 20 to 2500 mm.');
      return;
    }
    setState(() => busy = true);
    try {
      final pdf = await (widget.pdfGenerator ?? createScanPdfInBackground)(
        ScanPdfRequest(
          [for (final page in pages) page.image.bytes],
          paper: paper,
          pageWidthMm: pageWidth,
          pageHeightMm: pageHeight,
          autoRotatePaper: autoRotatePaper,
        ),
      );
      if (!mounted) return;
      final save = await showDialog<bool>(
        context: context,
        useRootNavigator: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('PDF ready to save'),
          content: SingleChildScrollView(
            child: Text(
              '${pages.length} page(s) · ${pageWidthController.text} × ${pageHeightController.text} mm · ${pdf.length} bytes\n\nThe page images shown in the draft are embedded in order, with 10 mm margins. ${autoRotatePaper ? 'Paper orientation follows each page image.' : 'The selected paper orientation is retained.'} This is an image PDF: it does not contain OCR or searchable text.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('scan-save-pdf'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Choose destination'),
            ),
          ],
        ),
      );
      if (save == true) {
        final saved = await widget.files.save(
          name: 'desksuite-document.pdf',
          bytes: pdf,
          mimeType: 'application/pdf',
        );
        if (saved) {
          // Exporting is non-destructive. Keep the one-step undo attached to
          // the page that was exported so the user can still undo its last edit
          // after the save dialog closes. Selection cannot change while busy.
          if (undoImage != null && pages.isNotEmpty && mounted) {
            setState(() => undoId = pages[selected].id);
          }
          message(
            'PDF exported. Open it in a PDF reader to verify the result.',
          );
        }
      }
    } catch (e) {
      message(
        readableError(
          e,
          'Could not create or save the PDF. Try again or choose another destination.',
        ),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (loading) return const Center(child: CircularProgressIndicator());
    if (loadError != null) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Scan draft unavailable',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(loadError!),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: busy ? null : _load,
                child: const Text('Retry'),
              ),
              OutlinedButton(
                onPressed: busy ? null : _discard,
                child: const Text('Discard draft'),
              ),
            ],
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Text(
          'Scan & assemble',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text(
          'Capture or import pages, correct and clean them, then save an image PDF. Originals are not changed automatically.',
        ),
        const SizedBox(height: 12),
        if (recovered != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recoveryAdded
                        ? 'The camera image is in the unsaved draft. Retry saving or export the original.'
                        : 'A camera image is waiting to be added or exported.',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton(
                        key: const Key('scan-add-recovered'),
                        onPressed: busy || recoveryAdded ? null : _addRecovered,
                        child: const Text('Add recovered page'),
                      ),
                      OutlinedButton(
                        onPressed: busy ? null : _saveRecovered,
                        child: const Text('Export recovered original'),
                      ),
                      TextButton(
                        onPressed: busy || recoveryAdded
                            ? null
                            : _dismissRecovered,
                        child: const Text('Dismiss'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        if (saveError != null)
          Card(
            color: scheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(saveError!),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () async {
                            setState(() => busy = true);
                            await _persist();
                            if (mounted) setState(() => busy = false);
                          },
                    child: const Text('Retry saving draft'),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              key: const Key('scan-import'),
              onPressed: busy || pages.length >= maxScanPages ? null : _import,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Add image'),
            ),
            if (widget.camera != null)
              OutlinedButton.icon(
                key: const Key('scan-camera'),
                onPressed:
                    busy || recovered != null || pages.length >= maxScanPages
                    ? null
                    : _capture,
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Use camera'),
              ),
            OutlinedButton.icon(
              key: const Key('scan-samples'),
              onPressed: busy ? null : _samples,
              icon: const Icon(Icons.school_outlined),
              label: const Text('Try an example'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          pages.isEmpty
              ? 'No pages yet. Add an image or try an example.'
              : '${pages.length} of $maxScanPages pages · ${saveError == null ? 'Draft saved on this device' : 'Draft not saved'}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (busy)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(
              semanticsLabel: 'Processing or saving page',
            ),
          ),
        if (pages.isNotEmpty) ...[
          const SizedBox(height: 14),
          for (var i = 0; i < pages.length; i++)
            Card(
              child: ListTile(
                key: Key('scan-page-$i'),
                selected: selected == i,
                onTap: busy
                    ? null
                    : () => setState(() {
                        selected = i;
                      }),
                leading: SizedBox(
                  width: 42,
                  height: 52,
                  child: Image.memory(
                    pages[i].image.bytes,
                    fit: BoxFit.contain,
                    cacheWidth: 100,
                  ),
                ),
                title: Text('Page ${i + 1}'),
                subtitle: Text(
                  '${pages[i].image.width} × ${pages[i].image.height} px',
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: selected == i
                    ? const Icon(Icons.check_circle_outline)
                    : null,
              ),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const Key('scan-move-up'),
                onPressed: busy || selected == 0 ? null : () => _move(-1),
                icon: const Icon(Icons.arrow_upward),
                label: const Text('Move up'),
              ),
              OutlinedButton.icon(
                key: const Key('scan-move-down'),
                onPressed: busy || selected == pages.length - 1
                    ? null
                    : () => _move(1),
                icon: const Icon(Icons.arrow_downward),
                label: const Text('Move down'),
              ),
              OutlinedButton.icon(
                key: const Key('scan-remove'),
                onPressed: busy ? null : _remove,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remove page'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Selected page ${selected + 1}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Container(
            height: 320,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Image.memory(
              pages[selected].image.bytes,
              fit: BoxFit.contain,
              cacheWidth: pages[selected].image.width > 1200
                  ? 1200
                  : pages[selected].image.width,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<CorrectionAspect>(
            key: const Key('scan-crop-aspect'),
            initialValue: correctionAspect,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Corner correction proportions',
            ),
            items: [
              for (final option in CorrectionAspect.values)
                DropdownMenuItem(value: option, child: Text(option.label)),
            ],
            onChanged: busy
                ? null
                : (value) {
                    if (value != null) setState(() => correctionAspect = value);
                  },
          ),
          const SizedBox(height: 6),
          const Text(
            'Edge estimates may not match paper proportions; choose a known page shape when needed. Changing proportions resamples pixels.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const Key('scan-crop'),
                onPressed: busy ? null : _crop,
                icon: const Icon(Icons.crop_free),
                label: const Text('Corners & correct'),
              ),
              FilledButton.tonalIcon(
                key: const Key('scan-cleanup'),
                onPressed: busy ? null : _cleanup,
                icon: const Icon(Icons.auto_fix_high),
                label: const Text('Clean up & compare'),
              ),
              OutlinedButton.icon(
                key: const Key('scan-rotate'),
                onPressed: busy
                    ? null
                    : () => _edit(
                        (image) => processPhoto(
                          PhotoRequest(image.bytes, PhotoAction.rotate90),
                        ),
                      ),
                icon: const Icon(Icons.rotate_right),
                label: const Text('Rotate'),
              ),
              OutlinedButton(
                key: const Key('scan-gray'),
                onPressed: busy
                    ? null
                    : () => _edit(
                        (image) => processPage(
                          ScanRequest(image.bytes, tone: ScanTone.grayscale),
                        ),
                      ),
                child: const Text('Grayscale'),
              ),
              OutlinedButton(
                key: const Key('scan-bw'),
                onPressed: busy
                    ? null
                    : () => _edit(
                        (image) => processPage(
                          ScanRequest(
                            image.bytes,
                            tone: ScanTone.blackAndWhite,
                          ),
                        ),
                      ),
                child: const Text('Black & white'),
              ),
              OutlinedButton(
                key: const Key('scan-undo'),
                onPressed: busy || undoId != pages[selected].id ? null : _undo,
                child: const Text('Undo last edit'),
              ),
              OutlinedButton(
                key: const Key('scan-reset'),
                onPressed: busy ? null : _reset,
                child: const Text('Reset page'),
              ),
              OutlinedButton.icon(
                key: const Key('scan-extract-text'),
                onPressed: busy ? null : _openTextExtraction,
                icon: const Icon(Icons.text_fields),
                label: const Text('Extract text from this page'),
              ),
              OutlinedButton(
                onPressed: busy ? null : _exportPage,
                child: const Text('Export page PNG'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Clean up & compare offers Original, Lighten, shadow reduction, Magic Pro, grayscale and adaptive black-and-white previews. These local heuristics can alter details and do not recover obscured text. The separate Black & white button uses a fixed threshold. Reset returns to the imported page copy.',
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<int>(
            key: const Key('scan-paper-preset'),
            initialValue: paperPresetIndex,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'PDF sheet / page size',
            ),
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
            onChanged: busy ? null : _selectPaperPreset,
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('scan-page-width'),
                  controller: pageWidthController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Width (mm)'),
                  onChanged: (_) {
                    if (paperPresetIndex != paperSheetPresets.length) {
                      setState(
                        () => paperPresetIndex = paperSheetPresets.length,
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  key: const Key('scan-page-height'),
                  controller: pageHeightController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Height (mm)'),
                  onChanged: (_) {
                    if (paperPresetIndex != paperSheetPresets.length) {
                      setState(
                        () => paperPresetIndex = paperSheetPresets.length,
                      );
                    }
                  },
                ),
              ),
            ],
          ),
          CheckboxListTile(
            key: const Key('scan-auto-rotate-paper'),
            contentPadding: EdgeInsets.zero,
            value: autoRotatePaper,
            title: const Text('Rotate paper to match each page image'),
            onChanged: busy
                ? null
                : (value) => setState(() => autoRotatePaper = value ?? true),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                key: const Key('scan-pdf'),
                onPressed: busy ? null : _pdf,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Prepare PDF'),
              ),
              TextButton(
                onPressed: busy ? null : _discard,
                child: const Text('Discard draft'),
              ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        const Text(
          'This tool creates image-only PDFs. Use Text extraction to review OCR and create searchable PDFs, or PDF Studio to open and edit an existing PDF. Draft pages stay on this device until discarded; export a copy for backup.',
        ),
      ],
    );
  }
}
