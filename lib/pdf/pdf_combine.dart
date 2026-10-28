import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:pdf_document/pdf_document.dart';

import 'pdf_inspection.dart';

/// Raised with a message a user can act on, never with a raw parser trace.
const int maxPdfCombineDocuments = 10;
const int maxPdfCombineBytes = 48 * 1024 * 1024;

class PdfCombineFailure implements Exception {
  const PdfCombineFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// The result of joining documents: new bytes plus what the engine reports
/// about them, so the UI never has to guess the page count.
class PdfCombineResult {
  const PdfCombineResult({required this.bytes, required this.sourcePageCounts});

  final Uint8List bytes;

  /// Page count of each input, in the order they were joined. The sum is the
  /// merged document's page count, which is asserted by the inspection below.
  final List<int> sourcePageCounts;

  int get pageCount => sourcePageCounts.fold(0, (sum, count) => sum + count);
  int get documentCount => sourcePageCounts.length;

  PdfInspection get inspection => inspectPdf(bytes);
}

/// Joins [sources] in order into one new PDF, without touching the originals.
///
/// Every input is validated first, with the same rules that guard the editor
/// screen, so a bad file is reported before any work is done and the message
/// names the file. Merging is done by the on-device engine — the later
/// documents are imported into the first one — and the output is inspected
/// again before it is returned, so a broken merge fails loudly instead of
/// handing back a file that will not open.
PdfCombineResult combinePdfs(List<Uint8List> sources) {
  if (sources.length < 2) {
    throw const PdfCombineFailure(
      'Choose at least two PDFs to combine. A single document is already one '
      'file.',
    );
  }
  if (sources.length > maxPdfCombineDocuments) {
    throw const PdfCombineFailure('Combine no more than 10 PDF files at once.');
  }
  final totalBytes = sources.fold<int>(0, (sum, bytes) => sum + bytes.length);
  if (totalBytes > maxPdfCombineBytes) {
    throw const PdfCombineFailure(
      'The selected PDFs exceed the 48 MB combined working limit. Remove a file or choose smaller copies.',
    );
  }
  final counts = <int>[];
  for (var i = 0; i < sources.length; i++) {
    final label = 'File ${i + 1}';
    final PdfInspection report;
    try {
      report = inspectPdf(sources[i]);
    } on PdfOpenFailure catch (failure) {
      throw PdfCombineFailure('$label cannot be combined: ${failure.message}');
    }
    counts.add(report.pageCount);
  }

  final Uint8List merged;
  try {
    merged = PdfMerger.merge(sources);
  } catch (error) {
    final message = '$error'.toLowerCase();
    if (message.contains('password')) {
      throw const PdfCombineFailure(
        'One of these PDFs is password-protected. Unlocking is not available '
        'yet, so DeskSuite will not pretend it combined the file.',
      );
    }
    throw const PdfCombineFailure(
      'These PDFs could not be combined. One of them may be damaged or use a '
      'feature the engine does not support. Your original files have not been '
      'changed.',
    );
  }

  final expected = counts.fold(0, (sum, count) => sum + count);
  final PdfInspection produced;
  try {
    produced = inspectPdf(merged);
  } on PdfOpenFailure catch (failure) {
    throw PdfCombineFailure(
      'The combined file did not come out readable: ${failure.message}',
    );
  }
  if (produced.pageCount != expected) {
    throw PdfCombineFailure(
      'The engine produced ${produced.pageCount} page(s) but these files have '
      '$expected. Nothing was saved, so your originals are untouched.',
    );
  }
  return PdfCombineResult(
    bytes: Uint8List.fromList(merged),
    sourcePageCounts: List.unmodifiable(counts),
  );
}

/// File name for a combined document: the first input's base name plus
/// `-combined`, sanitised the same way as every other PDF export.
String combinedPdfName(String firstSourceName) =>
    '${pdfBaseName(firstSourceName)}-combined.pdf';


/// Isolate-safe adapter for UI use. Only sendable byte lists and primitive
/// result values cross the isolate boundary; parser work stays off the UI.
Future<PdfCombineResult> combinePdfsInBackground(
  List<Uint8List> sources,
) async {
  final raw = await compute(_combinePdfsWorker, sources);
  final error = raw['error'];
  if (error is String) throw PdfCombineFailure(error);
  final bytes = raw['bytes'];
  final counts = raw['counts'];
  if (bytes is! Uint8List || counts is! List) {
    throw const PdfCombineFailure('The PDF engine returned an invalid result.');
  }
  return PdfCombineResult(
    bytes: bytes,
    sourcePageCounts: List<int>.unmodifiable(counts.cast<int>()),
  );
}

Map<String, Object> _combinePdfsWorker(List<Uint8List> sources) {
  try {
    final result = combinePdfs(sources);
    return <String, Object>{
      'bytes': result.bytes,
      'counts': result.sourcePageCounts,
    };
  } on PdfCombineFailure catch (failure) {
    return <String, Object>{'error': failure.message};
  } catch (_) {
    return <String, Object>{
      'error': 'The PDF engine could not safely combine these files.',
    };
  }
}
