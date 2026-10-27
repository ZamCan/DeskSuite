import 'dart:io';

import 'package:desksuite/design/design_document.dart';
import 'package:desksuite/workspace/project_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temp;
  late ProjectRepository repository;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('desksuite_test_');
    repository = ProjectRepository(temp);
  });
  tearDown(() async {
    await temp.delete(recursive: true);
  });

  test('save, close, reopen and import without overwriting', () async {
    final doc = DesignDocument.blank(
      name: 'My design',
      widthMm: 210,
      heightMm: 297,
    );
    await repository.save(doc);
    final reopened = await ProjectRepository(temp).load(doc.id);
    expect(reopened.name, 'My design');
    expect(reopened.widthMm, 210);
    final imported = await repository.import(doc.encode());
    expect(imported.id, isNot(doc.id));
    expect((await repository.list()).projects.length, 2);
    expect((await repository.load(doc.id)).name, 'My design');
  });

  test(
    'queued writes leave the newest complete document and no temp files',
    () async {
      final doc = DesignDocument.blank(
        name: 'First',
        widthMm: 100,
        heightMm: 100,
      );
      await Future.wait([
        repository.save(doc),
        repository.save(doc.copyWith(name: 'Second')),
      ]);
      expect((await repository.load(doc.id)).name, 'Second');
      expect(
        (await Directory(
          '${temp.path}/projects',
        ).list().toList()).where((f) => f.path.endsWith('.tmp')),
        isEmpty,
      );
    },
  );

  test('malformed project is reported without modifying it', () async {
    final projects = Directory('${temp.path}/projects');
    await projects.create();
    final file = File('${projects.path}/broken.dsdesign');
    await file.writeAsString('not a project');
    final list = await repository.list();
    expect(list.unreadableFiles, ['broken.dsdesign']);
    expect(await file.readAsString(), 'not a project');
    expect(() => repository.load('../escape'), throwsFormatException);
  });

  test(
    'settings and destructive deletion survive a fresh repository instance',
    () async {
      await repository.writeDarkMode(true);
      expect(await ProjectRepository(temp).readDarkMode(), isTrue);
      final settings = File('${temp.path}/settings.json');
      await settings.rename('${settings.path}.bak');
      expect(await ProjectRepository(temp).readDarkMode(), isTrue);
      expect(await settings.exists(), isTrue);
      final doc = DesignDocument.blank(
        name: 'Delete',
        widthMm: 100,
        heightMm: 100,
      );
      await repository.save(doc);
      await repository.delete(doc.id);
      expect((await repository.list()).projects, isEmpty);
    },
  );
  test(
    'a failed save preserves the prior version and the queue can recover',
    () async {
      if (Platform.isWindows) return;
      final doc = DesignDocument.blank(
        name: 'Safe copy',
        widthMm: 100,
        heightMm: 100,
      );
      await repository.save(doc);
      final directory = Directory('${temp.path}/projects');
      final chmod = await Process.run('chmod', ['500', directory.path]);
      expect(chmod.exitCode, 0);
      try {
        await expectLater(
          repository.save(doc.copyWith(name: 'Failed write')),
          throwsA(isA<FileSystemException>()),
        );
      } finally {
        await Process.run('chmod', ['700', directory.path]);
      }
      expect((await repository.load(doc.id)).name, 'Safe copy');
      await repository.save(doc.copyWith(name: 'Recovered'));
      expect((await repository.load(doc.id)).name, 'Recovered');
    },
  );

  test(
    'an interrupted replacement backup is recoverable from the project list',
    () async {
      final doc = DesignDocument.blank(
        name: 'Recovered backup',
        widthMm: 100,
        heightMm: 100,
      );
      await repository.save(doc);
      final file = File('${temp.path}/projects/${doc.id}.dsdesign');
      await file.rename('${file.path}.bak');
      expect(
        (await repository.list()).projects.single.name,
        'Recovered backup',
      );
      expect((await repository.load(doc.id)).name, 'Recovered backup');
    },
  );
}
