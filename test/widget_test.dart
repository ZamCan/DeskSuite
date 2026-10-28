import 'dart:io';
import 'dart:typed_data';

import 'package:desksuite/main.dart';
import 'package:desksuite/workspace/file_gateway.dart';
import 'package:desksuite/workspace/project_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _NoFiles implements FileGateway {
  @override
  Future<Uint8List?> pickImage() async => null;

  @override
  Future<Uint8List?> pickProject() async => null;

  @override
  Future<bool> save({
    required String name,
    required Uint8List bytes,
    required String mimeType,
  }) async => false;
}

void main() {
  testWidgets('DeskSuite starts without a static connectivity status', (
    tester,
  ) async {
    final dir = await tester.runAsync(
      () => Directory.systemTemp.createTemp('desksuite_smoke_'),
    );
    expect(dir, isNotNull);
    final repo = ProjectRepository(dir!);
    await tester.pumpWidget(
      DeskSuiteApp(
        showStartupAnimation: false,
        repository: repo,
        fileGateway: _NoFiles(),
      ),
    );
    for (var i = 0; i < 100 && find.text('Workspace').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }
    expect(find.text('Workspace'), findsWidgets);
    expect(find.text('Offline'), findsNothing);
    expect(find.text('LOCAL WORKSPACE'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.runAsync(() => dir.delete(recursive: true));
  });
}
