import 'dart:io';

import 'package:desksuite/core/local_file_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local writes queue, recover backups, reject paths, and recover after failure', () async {
    final dir = await Directory.systemTemp.createTemp('desksuite_local_');
    addTearDown(() => dir.delete(recursive: true));
    final store = LocalFileStore(() async => dir);
    await Future.wait([
      store.writeText('notes.txt', 'one'),
      store.writeText('notes.txt', 'two'),
    ]);
    expect(await store.readText('notes.txt'), 'two');
    final f = File('${dir.path}/notes.txt');
    await f.rename('${f.path}.bak');
    expect(await store.readText('notes.txt'), 'two');
    await expectLater(
      store.writeText('../escape', 'bad'),
      throwsFormatException,
    );
    await expectLater(
      store.writeEarlierProject('../escape', [1]),
      throwsFormatException,
    );
    await store.writeText('notes.txt', 'three');
    expect(await store.readText('notes.txt'), 'three');
    expect(
      (await dir.list().toList()).where((file) => file.path.endsWith('.tmp')),
      isEmpty,
    );
  });
}
