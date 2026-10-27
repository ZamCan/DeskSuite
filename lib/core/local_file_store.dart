import 'dart:convert';
import 'dart:io';

import 'atomic_file_store.dart';
import 'ids.dart';

/// Serializes app-private writes; callers can inject a root for tests.
class LocalFileStore {
  LocalFileStore(this.root);
  final Future<Directory> Function() root;
  Future<void> _tail = Future.value();

  Future<void> waitForWrites() => _tail;

  Future<void> _enqueue(Future<void> Function() action) {
    final work = _tail.then((_) => action());
    _tail = work.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return work;
  }

  File _localFile(Directory root, String name) {
    if (!RegExp(r'^[a-zA-Z0-9_.-]{1,128}$').hasMatch(name) ||
        name == '.' ||
        name == '..') {
      throw const FormatException('Invalid local file name.');
    }
    return File('${root.path}${Platform.pathSeparator}$name');
  }

  Future<void> writeText(String name, String value) => _enqueue(() async {
    final file = _localFile(await root(), name);
    final bytes = utf8.encode(value);
    if (bytes.length > 10 * 1024 * 1024) {
      throw const FormatException('Local text exceeds the 10 MB limit.');
    }
    await replaceFileAtomically(file, bytes);
  });

  Future<String> readText(String name, [String fallback = '']) async {
    await _tail;
    final file = _localFile(await root(), name);
    await recoverAtomicBackup(file);
    if (!await file.exists()) return fallback;
    if (await file.length() > 10 * 1024 * 1024) {
      throw const FormatException('Local text exceeds the 10 MB limit.');
    }
    return file.readAsString();
  }

  Future<void> writeEarlierProject(String id, List<int> bytes) =>
      _enqueue(() async {
        if (!isSafeId(id)) {
          throw const FormatException('Invalid project identifier.');
        }
        if (bytes.length > 32 * 1024 * 1024) {
          throw const FormatException('Project exceeds the 32 MB limit.');
        }
        final directory = Directory(
          '${(await root()).path}${Platform.pathSeparator}projects',
        );
        final file = File(
          '${directory.path}${Platform.pathSeparator}$id.dsproject',
        );
        await replaceFileAtomically(file, bytes);
      });
}
