import 'package:desksuite/ocr/ocr_engine.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(TesseractOcrEngine.channelName);

  void mock(Future<Object?> Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, handler);
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('TesseractOcrEngine', () {
    test('decodes native text, boxes and confidence', () async {
      mock((call) async {
        expect(call.method, 'recognize');
        final args = call.arguments as Map<Object?, Object?>;
        expect(args['language'], 'eng+swa');
        expect(args['bytes'], isA<Uint8List>());
        return <String, Object?>{
          'text': 'INVOICE 001\nTotal 5,000',
          'width': 800,
          'height': 1000,
          'language': 'eng+swa',
          'words': <Object?>[
            <String, Object?>{
              'text': 'INVOICE',
              'left': 10,
              'top': 20,
              'right': 110,
              'bottom': 50,
              'confidence': 91.5,
            },
            <String, Object?>{
              'text': '001',
              'left': 120,
              'top': 20,
              'right': 160,
              'bottom': 50,
              'confidence': 45.0,
            },
            <String, Object?>{
              'text': 'Total',
              'left': 10,
              'top': 80,
              'right': 60,
              'bottom': 104,
              'confidence': 88.0,
            },
          ],
        };
      });

      final engine = TesseractOcrEngine(channel: channel);
      final result = await engine.recognize(
        imageBytes: Uint8List.fromList([1, 2, 3, 4]),
        language: 'eng+swa',
      );

      expect(result.text, 'INVOICE 001\nTotal 5,000');
      expect(result.words, hasLength(3));
      expect(result.words.first.text, 'INVOICE');
      expect(result.words.first.width, 100);
      expect(result.imageWidth, 800);
      expect(result.imageHeight, 1000);
      expect(result.language, 'eng+swa');
      expect(result.meanConfidence, closeTo((91.5 + 45.0 + 88.0) / 3, .001));
      expect(result.words[1].isLowConfidence, isTrue);
      expect(result.lowConfidenceShare, closeTo(1 / 3, .001));
    });

    test('reports an unavailable engine instead of an empty success', () async {
      final engine = TesseractOcrEngine(channel: const MethodChannel('nope'));
      expect(await engine.isAvailable(), isFalse);
      expect(await engine.availableLanguages(), isEmpty);
      expect(
        () => engine.recognize(imageBytes: Uint8List.fromList([9, 9])),
        throwsA(isA<OcrUnavailable>()),
      );
    });

    test('surfaces a native failure as OcrFailure with its message', () async {
      mock((call) async {
        throw PlatformException(code: 'model', message: 'Model not found.');
      });
      final engine = TesseractOcrEngine(channel: channel);
      await expectLater(
        engine.recognize(imageBytes: Uint8List.fromList([1, 2])),
        throwsA(
          isA<OcrFailure>().having(
            (e) => e.message,
            'message',
            'Model not found.',
          ),
        ),
      );
    });

    test('rejects an empty image before touching the platform', () async {
      var called = false;
      mock((call) async {
        called = true;
        return null;
      });
      final engine = TesseractOcrEngine(channel: channel);
      await expectLater(
        engine.recognize(imageBytes: Uint8List(0)),
        throwsA(isA<OcrFailure>()),
      );
      expect(called, isFalse);
    });

    test('reports availability and languages from the platform', () async {
      mock((call) async {
        if (call.method == 'isAvailable') return true;
        if (call.method == 'availableLanguages') return <String>['eng', 'swa'];
        return null;
      });
      final engine = TesseractOcrEngine(channel: channel);
      expect(await engine.isAvailable(), isTrue);
      expect(await engine.availableLanguages(), ['eng', 'swa']);
    });
  });

  group('OcrResult model', () {
    test('round-trips a word through JSON', () {
      const word = OcrWord(
        text: 'Kiswahili',
        left: 1,
        top: 2,
        right: 30,
        bottom: 14,
        confidence: 77.5,
      );
      final decoded = OcrWord.fromJson(word.toJson());
      expect(decoded.text, 'Kiswahili');
      expect(decoded.left, 1);
      expect(decoded.bottom, 14);
      expect(decoded.confidence, 77.5);
    });

    test('treats missing confidence as unknown, not as a failure', () {
      final word = OcrWord.fromJson(const {'text': 'x', 'left': 0.4});
      expect(word.confidence, isNull);
      expect(word.isLowConfidence, isFalse);
      expect(word.left, 0);
    });

    test('empty result is reported as empty', () {
      expect(OcrResult.empty.isEmpty, isTrue);
      expect(OcrResult.empty.lowConfidenceShare, 0);
    });
  });
}
