import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:desksuite/design/design_document.dart';
import 'package:desksuite/workspace/project_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final image = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAMCAIAAADkharWAAAAF0lEQVR4nGPs2VLBQApgIkn1qIYRpAEADVwB0JlVGsIAAAAASUVORK5CYII=',
  );
  Map<String, dynamic> legacy() => {
    'schemaVersion': 1,
    'id': '1700000000000000',
    'name': 'Earlier poster',
    'width': 360.0,
    'height': 480.0,
    'updated': '2026-10-27T12:30:00.000Z',
    'items': [
      {
        'id': '1',
        'kind': 'text',
        'text': 'Hello',
        'x': 10.0,
        'y': 20.0,
        'w': 100.0,
        'h': 50.0,
        'color': 0xff292b29,
        'size': 24.0,
      },
      {
        'id': '2',
        'kind': 'circle',
        'text': '',
        'x': 25.0,
        'y': 30.0,
        'w': 80.0,
        'h': 70.0,
        'color': 0xffb56b45,
        'size': 24.0,
      },
      {
        'id': '3',
        'kind': 'image',
        'text': 'photo.png',
        'x': 40.0,
        'y': 45.0,
        'w': 70.0,
        'h': 60.0,
        'color': 0xff292b29,
        'size': 24.0,
        'imageData': base64Encode(image),
      },
    ],
  };

  test('earlier .dsproject becomes an editable copy without overwriting its source', () async {
    final dir = await Directory.systemTemp.createTemp('desksuite_legacy_');
    addTearDown(() => dir.delete(recursive: true));
    final original = File('${dir.path}/earlier.dsproject');
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(legacy())));
    await original.writeAsBytes(bytes);
    final repo = ProjectRepository(Directory('${dir.path}/new-app'));
    final doc = await repo.import(bytes);
    expect(doc.id, isNot('1700000000000000'));
    expect(doc.name, 'Earlier poster');
    expect(doc.widthMm, closeTo(95.25, .001));
    expect(doc.heightMm, closeTo(127, .001));
    expect(doc.elements.map((e) => e.kind), [
      ElementKind.text,
      ElementKind.ellipse,
      ElementKind.image,
    ]);
    expect(doc.elements.first.text, 'Hello');
    expect(doc.elements.first.fontSizePt, 18);
    expect(doc.elements.first.bold, isTrue);
    expect(doc.elements.last.imageBytes, orderedEquals(image));
    expect(await original.readAsBytes(), orderedEquals(bytes));
    final reopened = await ProjectRepository(Directory('${dir.path}/new-app'))
        .load(doc.id);
    expect(reopened.toJson()['format'], 'desksuite.design');
    expect(reopened.elements.length, 3);
  });

  test('legacy import rejects unsafe data and excessively nested JSON', () {
    final invalid = legacy();
    (invalid['items'] as List).first['kind'] = 'unknown';
    expect(
      () => DesignDocument.decode(utf8.encode(jsonEncode(invalid))),
      throwsFormatException,
    );
    final nested = '${'[' * 33}0${']' * 33}';
    expect(
      () => DesignDocument.decode(utf8.encode(nested)),
      throwsFormatException,
    );
    invalid['schemaVersion'] = 99;
    expect(
      () => DesignDocument.decode(utf8.encode(jsonEncode(invalid))),
      throwsFormatException,
    );
  });
  test(
    'finds earlier private files and imports a copy without deleting originals',
    () async {
      final root = await Directory.systemTemp.createTemp('desksuite_old_root_');
      addTearDown(() => root.delete(recursive: true));
      final folder = Directory('${root.path}/projects');
      await folder.create();
      final old = File('${folder.path}/1700000000000000.dsproject');
      final oldBytes = utf8.encode(jsonEncode(legacy()));
      await old.writeAsBytes(oldBytes);
      final bad = File('${folder.path}/damaged.dsproject');
      await bad.writeAsString('{oops');
      final repo = ProjectRepository(root);
      await old.rename('${old.path}.bak');
      final list = await repo.listLegacy();
      expect(await old.exists(), isTrue);
      expect(list.projects.single.name, 'Earlier poster');
      expect(list.unreadableFiles, ['damaged.dsproject']);
      final copy = await repo.importLegacy(list.projects.single.id);
      expect(copy.id, isNot(list.projects.single.id));
      expect((await repo.load(copy.id)).elements.length, 3);
      expect(await old.readAsBytes(), orderedEquals(oldBytes));
      expect(await bad.readAsString(), '{oops');
      await expectLater(repo.importLegacy('../escape'), throwsFormatException);
    },
  );
}
