import 'dart:io';
import 'dart:typed_data';

import 'package:desksuite/core/atomic_file_store.dart';
import 'package:desksuite/document_scan/scan_draft_store.dart';
import 'package:desksuite/images/photo_processor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

PhotoResult sample(int width, int height, int red) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(red, 60, 30));
  return PhotoResult(Uint8List.fromList(img.encodePng(image)), width, height);
}

void main() {
  late Directory temp;
  late ScanDraftStore store;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('desksuite-scan-');
    store = ScanDraftStore(Directory('${temp.path}/draft'));
  });
  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test(
    'saves, restores, reorders, edits and resets without modifying originals',
    () async {
      final first = sample(4, 6, 20), second = sample(6, 4, 80);
      final firstBytes = Uint8List.fromList(first.bytes);
      var pages = await store.save([
        ScanDraftPage(original: first, image: first),
        ScanDraftPage(original: second, image: second),
      ]);
      expect(pages[0].originalFile, pages[0].imageFile);
      final edited = sample(2, 3, 150);
      pages = await store.save([pages[1], pages[0].withImage(edited)]);
      expect(pages[1].imageFile, isNot(pages[1].originalFile));
      final restored = await store.load();
      expect(restored.map((p) => p.id), [pages[0].id, pages[1].id]);
      expect([restored[1].image.width, restored[1].image.height], [2, 3]);
      expect(restored[1].original.bytes, orderedEquals(firstBytes));
      final reset = restored[1].withImage(restored[1].original);
      final saved = await store.save([reset]);
      expect(saved.single.imageFile, saved.single.originalFile);
      final reopened = await store.load();
      expect(reopened.single.image.bytes, orderedEquals(firstBytes));
      expect(first.bytes, orderedEquals(firstBytes));
    },
  );

  test(
    'failed manifest replacement preserves the previously committed draft',
    () async {
      final original = sample(3, 5, 40);
      final committed = await store.save([
        ScanDraftPage(original: original, image: original),
      ]);
      final manifest = File('${store.root.path}/draft.json');
      final previous = await manifest.readAsString();
      final failing = ScanDraftStore(
        store.root,
        writeFile: (file, bytes) async {
          if (file.path.endsWith('draft.json')) {
            throw const FileSystemException('Simulated full storage');
          }
          await replaceFileAtomically(file, bytes);
        },
      );
      final updated = committed.single.withImage(sample(2, 4, 90));
      await expectLater(
        failing.save([updated]),
        throwsA(isA<FileSystemException>()),
      );
      expect(await manifest.readAsString(), previous);
      final restored = await store.load();
      expect(restored.single.image.bytes, orderedEquals(original.bytes));
      // A later successful save can recover and clean unreferenced assets.
      await store.save([updated]);
      expect((await store.load()).single.image.width, 2);
    },
  );

  test('invalid manifest and path traversal are reported, never overwritten', () async {
    await store.root.create(recursive: true);
    final manifest = File('${store.root.path}/draft.json');
    const malformed =
        '{"version":1,"pages":[{"id":"safe","original":"../secret.png","image":"../secret.png"}]}';
    await manifest.writeAsString(malformed);
    await expectLater(store.load(), throwsFormatException);
    expect(await manifest.readAsString(), malformed);
  });

  test('explicit discard removes only the scan draft', () async {
    final sibling = File('${temp.path}/untouched.txt');
    await sibling.writeAsString('user data');
    final image = sample(2, 3, 60);
    await store.save([ScanDraftPage(original: image, image: image)]);
    await store.discard();
    expect(await store.root.exists(), isFalse);
    expect(await sibling.readAsString(), 'user data');
  });
}
