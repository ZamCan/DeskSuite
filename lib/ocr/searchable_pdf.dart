import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'ocr_engine.dart';

/// One page of a searchable PDF: the visible page image plus the recognized
/// text placed, invisibly, over the words it came from.
class SearchablePage {
  const SearchablePage({required this.imageBytes, required this.result});

  final Uint8List imageBytes;
  final OcrResult result;
}

/// Geometry for fitting an image on a PDF page while keeping its aspect ratio.
///
/// Kept separate from rendering so the coordinate mapping can be asserted in
/// unit tests without decoding a PDF.
class PageFit {
  const PageFit({
    required this.width,
    required this.height,
    required this.offsetX,
    required this.offsetY,
    required this.scale,
  });

  final double width;
  final double height;
  final double offsetX;
  final double offsetY;

  /// PDF points per source-image pixel.
  final double scale;

  static PageFit contain({
    required int imageWidth,
    required int imageHeight,
    required PdfPageFormat format,
  }) {
    if (imageWidth <= 0 || imageHeight <= 0) {
      throw const FormatException('An OCR page needs a positive image size.');
    }
    final available = format.copyWith(
      marginLeft: 0,
      marginTop: 0,
      marginRight: 0,
      marginBottom: 0,
    );
    final areaWidth = available.width;
    final areaHeight = available.height;
    final scale = (areaWidth / imageWidth) < (areaHeight / imageHeight)
        ? areaWidth / imageWidth
        : areaHeight / imageHeight;
    final width = imageWidth * scale;
    final height = imageHeight * scale;
    return PageFit(
      width: width,
      height: height,
      offsetX: (areaWidth - width) / 2,
      offsetY: (areaHeight - height) / 2,
      scale: scale,
    );
  }

  /// Maps a recognized word box from image pixels into page points.
  PdfRect wordRect(OcrWord word) {
    final left = offsetX + word.left * scale;
    final top = offsetY + word.top * scale;
    final width = (word.width <= 0 ? 1 : word.width) * scale;
    final height = (word.height <= 0 ? 1 : word.height) * scale;
    return PdfRect(left, top, width, height);
  }
}

/// A rectangle in PDF points, origin at the page's top-left for layout use.
class PdfRect {
  const PdfRect(this.left, this.top, this.width, this.height);
  final double left;
  final double top;
  final double width;
  final double height;
  double get right => left + width;
  double get bottom => top + height;
}

/// Builds a PDF whose pages show the scan image and carry a real, selectable
/// text layer produced from OCR word geometry.
///
/// Limitations, deliberately not hidden:
/// - Only words the recognizer returned are searchable; nothing is invented.
/// - Text is placed per word box, so column and table reading order follows the
///   recognizer's line segmentation, not a reconstruction of the layout.
/// - The visible page is an image; this is not an editable text document.
Future<Uint8List> buildSearchablePdf(
  List<SearchablePage> pages, {
  String title = 'DeskSuite scan',
  PdfPageFormat? pageFormat,
}) async {
  if (pages.isEmpty) {
    throw const FormatException('A searchable PDF needs at least one page.');
  }
  final document = pw.Document(
    title: title,
    author: 'DeskSuite (ZamCan)',
    creator: 'DeskSuite offline scan + OCR',
  );
  var totalWords = 0;
  for (final page in pages) {
    if (page.imageBytes.isEmpty) {
      throw const FormatException('A page image is missing.');
    }
    final result = page.result;
    if (result.imageWidth <= 0 || result.imageHeight <= 0) {
      throw const FormatException('A page has no image dimensions.');
    }
    final format =
        pageFormat ??
        PdfPageFormat(
          // Match the scan's proportions at a printable width so the visible
          // page is not letterboxed with large empty bands.
          (result.imageWidth * (595.28 / result.imageWidth)).clamp(
            200.0,
            1400.0,
          ),
          (result.imageHeight * (595.28 / result.imageWidth)).clamp(
            200.0,
            2000.0,
          ),
        );
    final fit = PageFit.contain(
      imageWidth: result.imageWidth,
      imageHeight: result.imageHeight,
      format: format,
    );
    final image = pw.MemoryImage(page.imageBytes);
    totalWords += result.words.length;
    document.addPage(
      pw.Page(
        pageFormat: format,
        build: (context) => pw.Stack(
          children: [
            pw.Positioned(
              left: fit.offsetX,
              top: fit.offsetY,
              child: pw.SizedBox(
                width: fit.width,
                height: fit.height,
                child: pw.Image(image, fit: pw.BoxFit.fill),
              ),
            ),
            for (final word in result.words)
              if (word.text.trim().isNotEmpty)
                _invisibleWord(word, fit.wordRect(word)),
          ],
        ),
      ),
    );
  }
  if (totalWords == 0) {
    throw const FormatException(
      'No recognized words were available to build a searchable layer.',
    );
  }
  return document.save();
}

pw.Widget _invisibleWord(OcrWord word, PdfRect rect) {
  // A fully transparent text colour keeps the word selectable and searchable
  // while leaving the visible scan untouched.
  final fontSize = (rect.height * 0.94).clamp(2.0, 96.0);
  return pw.Positioned(
    left: rect.left,
    top: rect.top,
    child: pw.Text(
      word.text,
      maxLines: 1,
      style: pw.TextStyle(
        fontSize: fontSize.toDouble(),
        color: const PdfColor(0, 0, 0, 0),
      ),
    ),
  );
}
