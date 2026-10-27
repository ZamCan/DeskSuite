import 'package:flutter/services.dart';

/// A single recognized word with its bounding box in source-image pixels.
///
/// Coordinates are top-left based and measured against the image that was
/// handed to the engine. They are approximate: the recognizer reports boxes for
/// its own line segmentation, not typographic glyph metrics.
class OcrWord {
  const OcrWord({
    required this.text,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    this.confidence,
  });

  final String text;
  final int left;
  final int top;
  final int right;
  final int bottom;

  /// 0–100 where the engine reports it, or null when unavailable.
  final double? confidence;

  int get width => right - left;
  int get height => bottom - top;

  bool get isLowConfidence => confidence != null && confidence! < 70;

  Map<String, Object?> toJson() => {
    'text': text,
    'left': left,
    'top': top,
    'right': right,
    'bottom': bottom,
    'confidence': confidence,
  };

  static OcrWord fromJson(Map<String, Object?> json) => OcrWord(
    text: '${json['text'] ?? ''}',
    left: _int(json['left']),
    top: _int(json['top']),
    right: _int(json['right']),
    bottom: _int(json['bottom']),
    confidence: (json['confidence'] as num?)?.toDouble(),
  );

  static int _int(Object? value) => value is num ? value.round() : 0;
}

/// Recognition output for one image.
class OcrResult {
  const OcrResult({
    required this.text,
    required this.words,
    required this.imageWidth,
    required this.imageHeight,
    required this.language,
    this.engineLabel = 'Tesseract',
    this.meanConfidence,
  });

  /// Reading-order text with newlines between recognized lines.
  final String text;
  final List<OcrWord> words;
  final int imageWidth;
  final int imageHeight;
  final String language;
  final String engineLabel;

  /// Mean word confidence 0–100 when the engine reports confidence.
  final double? meanConfidence;

  bool get isEmpty => text.trim().isEmpty;

  /// Share of words the engine was unsure about, for honest quality warnings.
  double get lowConfidenceShare {
    if (words.isEmpty) return 0;
    final low = words.where((w) => w.isLowConfidence).length;
    return low / words.length;
  }

  static const empty = OcrResult(
    text: '',
    words: <OcrWord>[],
    imageWidth: 0,
    imageHeight: 0,
    language: 'eng',
  );
}

/// Raised when recognition cannot run at all — missing native engine, missing
/// language data, unreadable image. Callers must show the reason instead of an
/// empty result, because "no text found" and "engine unavailable" are different
/// outcomes for the user.
class OcrUnavailable implements Exception {
  const OcrUnavailable(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Raised when an image was accepted but recognition failed part-way.
class OcrFailure implements Exception {
  const OcrFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Offline text recognition boundary.
///
/// Implementations must never upload the image. Tests inject fakes; the Android
/// build supplies [TesseractOcrEngine].
abstract class OcrEngine {
  /// Human-readable engine name shown in the UI and export metadata.
  String get label;

  /// Whether the offline recognizer and at least one language model are usable
  /// on this device. Cheap enough to call when opening the screen.
  Future<bool> isAvailable();

  /// Languages this engine can recognize, as BCP-47-ish codes.
  Future<List<String>> availableLanguages();

  Future<OcrResult> recognize({
    required Uint8List imageBytes,
    String language = 'eng',
  });
}

/// Production engine: Tesseract 5 through Tesseract4Android, fully offline.
///
/// The native side extracts the bundled `tessdata` models into app-private
/// storage on first use, then recognizes a bounded copy of the image.
class TesseractOcrEngine implements OcrEngine {
  TesseractOcrEngine({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'com.zamcan.desksuite/ocr';

  /// Source images above this size are downsampled natively before decoding so
  /// recognition cannot exhaust memory on a modest phone.
  static const int maxSourcePixels = 12 * 1000 * 1000;

  final MethodChannel _channel;

  @override
  String get label => 'Tesseract 5 (on device)';

  @override
  Future<bool> isAvailable() async {
    try {
      final result = await _channel.invokeMethod<bool>('isAvailable');
      return result ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<List<String>> availableLanguages() async {
    try {
      final result = await _channel.invokeListMethod<String>(
        'availableLanguages',
      );
      return result ?? const <String>[];
    } on MissingPluginException {
      return const <String>[];
    } on PlatformException {
      return const <String>[];
    }
  }

  @override
  Future<OcrResult> recognize({
    required Uint8List imageBytes,
    String language = 'eng',
  }) async {
    if (imageBytes.isEmpty) {
      throw const OcrFailure('The image is empty.');
    }
    try {
      final raw = await _channel.invokeMapMethod<String, Object?>(
        'recognize',
        <String, Object?>{'bytes': imageBytes, 'language': language},
      );
      if (raw == null) {
        throw const OcrFailure('The recognizer returned no result.');
      }
      return _decode(raw, language);
    } on MissingPluginException {
      throw const OcrUnavailable(
        'Offline text recognition is not available in this build.',
      );
    } on PlatformException catch (error) {
      throw OcrFailure(
        error.message?.isNotEmpty == true
            ? error.message!
            : 'Recognition failed (${error.code}).',
      );
    }
  }

  OcrResult _decode(Map<String, Object?> raw, String language) {
    final words = <OcrWord>[];
    final rawWords = raw['words'];
    if (rawWords is List) {
      for (final entry in rawWords) {
        if (entry is Map) {
          words.add(
            OcrWord.fromJson(<String, Object?>{
              'text': entry['text'],
              'left': entry['left'],
              'top': entry['top'],
              'right': entry['right'],
              'bottom': entry['bottom'],
              'confidence': entry['confidence'],
            }),
          );
        }
      }
    }
    final confidenceValues = words
        .map((w) => w.confidence)
        .whereType<double>()
        .toList(growable: false);
    return OcrResult(
      text: '${raw['text'] ?? ''}'.trim(),
      words: words,
      imageWidth: (raw['width'] as num?)?.round() ?? 0,
      imageHeight: (raw['height'] as num?)?.round() ?? 0,
      language: '${raw['language'] ?? language}',
      engineLabel: label,
      meanConfidence: confidenceValues.isEmpty
          ? null
          : confidenceValues.reduce((a, b) => a + b) / confidenceValues.length,
    );
  }
}
