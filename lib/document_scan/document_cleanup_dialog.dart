import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../images/photo_processor.dart';
import 'document_cleanup.dart';

/// A preview is temporary. The caller receives a page only when the user
/// chooses Use cleaned page; cancelling never changes the draft.
class DocumentCleanupDialog extends StatefulWidget {
  const DocumentCleanupDialog({
    super.key,
    required this.page,
    required this.processor,
  });
  final PhotoResult page;
  final Future<PhotoResult> Function(DocumentCleanupRequest) processor;

  @override
  State<DocumentCleanupDialog> createState() => _DocumentCleanupDialogState();
}

class _DocumentCleanupDialogState extends State<DocumentCleanupDialog> {
  DocumentCleanupMode mode = DocumentCleanupMode.evenLighting;
  double amount = .7;
  PhotoResult? result;
  bool showAfter = false, busy = false;
  String? error;

  void _invalidate() {
    result = null;
    showAfter = false;
    error = null;
  }

  Future<void> _preview() async {
    if (busy) return;
    if (mode == DocumentCleanupMode.original) {
      // This is the current working page, not a reset to the imported file.
      setState(() {
        result = widget.page;
        showAfter = true;
        error = null;
      });
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final processed = await widget.processor(
        DocumentCleanupRequest(widget.page.bytes, mode: mode, amount: amount),
      );
      if (!mounted) return;
      setState(() {
        result = processed;
        showAfter = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        result = null;
        showAfter = false;
        error = e is FormatException
            ? e.message
            : 'Cleanup could not be prepared. The page has not changed.';
      });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = showAfter && result != null ? result! : widget.page;
    final textTheme = Theme.of(context).textTheme;
    final hasAmount =
        mode != DocumentCleanupMode.original &&
        mode != DocumentCleanupMode.grayscale;
    final amountLabel = mode == DocumentCleanupMode.adaptiveBlackAndWhite
        ? 'Mark sensitivity'
        : mode == DocumentCleanupMode.evenLighting
        ? 'Lighting strength'
        : 'Strength';
    final description = switch (mode) {
      DocumentCleanupMode.original => 'Keep the page as it was when this dialog opened. Reset page in the scan workspace returns to the imported page copy.',
      DocumentCleanupMode.lighten => 'Lifts the whole page, including shadow. Highlights may clip; this does not remove shadows.',
      DocumentCleanupMode.evenLighting => 'Tries to brighten shaded paper while retaining color. Severe shadows or artwork may still change.',
      DocumentCleanupMode.magicPro => 'Normalizes uneven lighting and boosts document contrast in color. Shadows may remain, and colors or faint marks can change.',
      DocumentCleanupMode.grayscale =>
        'Converts the page to shades of gray; it does not remove shadows.',
      DocumentCleanupMode.adaptiveBlackAndWhite => 'Makes only black and white pixels. Higher sensitivity keeps more dark marks but can retain shadows; light writing and color may be lost.',
    };
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: math.max(100.0, MediaQuery.sizeOf(context).height - 32),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Clean up page', style: textTheme.titleLarge),
                      const SizedBox(height: 8),
                      const Text(
                        'Pinch the preview to inspect details. Compare with the page before this cleanup; the draft changes only when you choose Use cleaned page.',
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 200,
                        width: double.infinity,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Semantics(
                          label: showAfter && result != null
                              ? 'Cleaned page preview'
                              : 'Page before cleanup',
                          child: InteractiveViewer(
                            key: const Key('cleanup-zoom'),
                            maxScale: 6,
                            child: Center(
                              child: Image.memory(
                                page.bytes,
                                key: Key(
                                  showAfter
                                      ? 'cleanup-after-image'
                                      : 'cleanup-before-image',
                                ),
                                fit: BoxFit.contain,
                                cacheWidth: math.min(page.width, 1200),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton.icon(
                            key: const Key('cleanup-before'),
                            onPressed: result == null || busy
                                ? null
                                : () => setState(() => showAfter = false),
                            icon: Icon(
                              !showAfter ? Icons.check : Icons.image_outlined,
                            ),
                            label: const Text('Before'),
                          ),
                          TextButton.icon(
                            key: const Key('cleanup-after'),
                            onPressed: result == null || busy
                                ? null
                                : () => setState(() => showAfter = true),
                            icon: Icon(
                              showAfter && result != null
                                  ? Icons.check
                                  : Icons.auto_fix_high,
                            ),
                            label: const Text('After'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<DocumentCleanupMode>(
                        key: const Key('cleanup-mode'),
                        initialValue: mode,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Cleanup method',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: DocumentCleanupMode.original,
                            child: Text('Original · current page'),
                          ),
                          DropdownMenuItem(
                            value: DocumentCleanupMode.lighten,
                            child: Text('Lighten · color'),
                          ),
                          DropdownMenuItem(
                            value: DocumentCleanupMode.evenLighting,
                            child: Text('Reduce shadows · color'),
                          ),
                          DropdownMenuItem(
                            value: DocumentCleanupMode.magicPro,
                            child: Text('Magic Pro · clean color'),
                          ),
                          DropdownMenuItem(
                            value: DocumentCleanupMode.grayscale,
                            child: Text('Grayscale'),
                          ),
                          DropdownMenuItem(
                            value: DocumentCleanupMode.adaptiveBlackAndWhite,
                            child: Text('Adaptive black & white'),
                          ),
                        ],
                        onChanged: busy
                            ? null
                            : (value) {
                                if (value == null) return;
                                setState(() {
                                  mode = value;
                                  // Each preset starts at its own recommended
                                  // strength; users can adjust before preview.
                                  amount = value == DocumentCleanupMode.magicPro
                                      ? .9
                                      : .7;
                                  _invalidate();
                                });
                              },
                      ),
                      const SizedBox(height: 8),
                      if (hasAmount) ...[
                        Text('$amountLabel: ${(amount * 100).round()}%'),
                        Slider(
                          key: const Key('cleanup-amount'),
                          value: amount,
                          min: 0,
                          max: 1,
                          divisions: 20,
                          label: '${(amount * 100).round()}%',
                          semanticFormatterCallback: (value) =>
                              '${(value * 100).round()} percent',
                          onChanged: busy
                              ? null
                              : (value) => setState(() {
                                  amount = value;
                                  _invalidate();
                                }),
                        ),
                      ],
                      Text(description),
                      const SizedBox(height: 8),
                      Text(
                        mode == DocumentCleanupMode.original
                            ? 'Original keeps transparency. Check every page before export.'
                            : 'Transparency is flattened to white. Check every page; cleanup cannot recover text hidden in the source.',
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      if (busy)
                        const LinearProgressIndicator(
                          semanticsLabel: 'Preparing cleanup preview',
                        )
                      else
                        OutlinedButton.icon(
                          key: const Key('cleanup-preview'),
                          onPressed: _preview,
                          icon: const Icon(Icons.preview_outlined),
                          label: Text(
                            result == null
                                ? 'Preview cleanup'
                                : 'Preview again',
                          ),
                        ),
                      if (result == null && !busy)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            'Change a setting, then preview to compare.',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              OverflowBar(
                alignment: MainAxisAlignment.end,
                spacing: 8,
                overflowSpacing: 4,
                children: [
                  TextButton(
                    key: const Key('cleanup-cancel'),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    key: const Key('cleanup-use'),
                    onPressed: busy || result == null
                        ? null
                        : () => Navigator.pop(context, result),
                    child: Text(
                      mode == DocumentCleanupMode.original
                          ? 'Keep current page'
                          : 'Use cleaned page',
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
