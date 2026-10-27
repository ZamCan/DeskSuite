import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../core/atomic_file_store.dart';
import '../core/ids.dart';
import '../design/design_document.dart';

class ProjectSummary {
  const ProjectSummary({
    required this.id,
    required this.name,
    required this.widthMm,
    required this.heightMm,
    required this.updatedAt,
    required this.layerCount,
  });
  final String id;
  final String name;
  final double widthMm;
  final double heightMm;
  final DateTime updatedAt;
  final int layerCount;
}

class ProjectList {
  const ProjectList(this.projects, this.unreadableFiles);
  final List<ProjectSummary> projects;
  final List<String> unreadableFiles;
}

/// Local files are versioned and saved via a same-directory temporary file.
class ProjectRepository {
  ProjectRepository(this.root, {this.legacyRoot});
  final Directory root;
  final Directory? legacyRoot;
  Future<void> _tail = Future.value();

  Directory get _projects =>
      Directory('${root.path}${Platform.pathSeparator}projects');
  Directory get _legacyProjects => Directory(
    '${(legacyRoot ?? root).path}${Platform.pathSeparator}projects',
  );

  File _projectFile(String id) {
    if (!isSafeId(id)) {
      throw const FormatException('Invalid project identifier.');
    }
    return File('${_projects.path}${Platform.pathSeparator}$id.dsdesign');
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final work = _tail.then((_) => action());
    _tail = work.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return work;
  }

  Future<void> save(DesignDocument document) => _enqueue(() async {
    final bytes = document.encode();
    if (bytes.length > maxProjectBytes) {
      throw const FormatException('Project exceeds the 32 MB limit.');
    }
    await replaceFileAtomically(_projectFile(document.id), bytes);
  });

  Future<DesignDocument> load(String id) async {
    await _tail;
    final file = _projectFile(id);
    final backup = File('${file.path}.bak');
    if (!await file.exists() && await backup.exists()) {
      await backup.rename(file.path);
    }
    if (await file.length() > maxProjectBytes) {
      throw const FormatException('Project exceeds the 32 MB limit.');
    }
    final doc = DesignDocument.decode(await file.readAsBytes());
    if (doc.id != id) {
      throw const FormatException('Mismatched project identifier.');
    }
    return doc;
  }

  Future<ProjectList> list() async {
    await _tail;
    if (!await _projects.exists()) return const ProjectList([], []);
    // Recover a Windows backup left by an interrupted replacement before listing.
    await for (final entity in _projects.list(followLinks: false)) {
      if (entity is File && entity.path.endsWith('.dsdesign.bak')) {
        final original = File(entity.path.substring(0, entity.path.length - 4));
        if (!await original.exists()) await entity.rename(original.path);
      }
    }
    final projects = <ProjectSummary>[];
    final unreadable = <String>[];
    await for (final entity in _projects.list(followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.dsdesign')) continue;
      final name = entity.uri.pathSegments.last;
      try {
        if (await entity.length() > maxProjectBytes) {
          throw const FormatException('Too large');
        }
        final doc = DesignDocument.decode(await entity.readAsBytes());
        // A mismatched embedded id must not cause another file to be modified.
        if (name != '${doc.id}.dsdesign') {
          throw const FormatException('Mismatched project id');
        }
        projects.add(
          ProjectSummary(
            id: doc.id,
            name: doc.name,
            widthMm: doc.widthMm,
            heightMm: doc.heightMm,
            updatedAt: doc.updatedAt,
            layerCount: doc.elements.length,
          ),
        );
      } catch (_) {
        unreadable.add(name);
      }
    }
    projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return ProjectList(projects, unreadable);
  }

  Future<void> delete(String id) => _enqueue(() async {
    final file = _projectFile(id);
    if (await file.exists()) await file.delete();
    final backup = File('${file.path}.bak');
    if (await backup.exists()) await backup.delete();
  });

  /// Lists earlier app-private projects without modifying them. Invalid files
  /// are reported rather than hidden or replaced with empty projects.
  Future<ProjectList> listLegacy() async {
    await _tail;
    if (!await _legacyProjects.exists()) return const ProjectList([], []);
    await for (final entity in _legacyProjects.list(followLinks: false)) {
      if (entity is File && entity.path.endsWith('.dsproject.bak')) {
        final original = File(entity.path.substring(0, entity.path.length - 4));
        await recoverAtomicBackup(original);
      }
    }
    final projects = <ProjectSummary>[];
    final unreadable = <String>[];
    await for (final entity in _legacyProjects.list(followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.dsproject')) continue;
      final name = entity.uri.pathSegments.last;
      try {
        if (await entity.length() > maxProjectBytes) {
          throw const FormatException('Too large');
        }
        final doc = DesignDocument.decode(await entity.readAsBytes());
        if (name != '${doc.id}.dsproject') {
          throw const FormatException('Mismatched project id');
        }
        projects.add(
          ProjectSummary(
            id: doc.id,
            name: doc.name,
            widthMm: doc.widthMm,
            heightMm: doc.heightMm,
            updatedAt: doc.updatedAt,
            layerCount: doc.elements.length,
          ),
        );
      } catch (_) {
        unreadable.add(name);
      }
    }
    projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return ProjectList(projects, unreadable);
  }

  /// Converts an earlier local project to a new editable copy, leaving the
  /// original in place for the earlier editor and for recovery.
  Future<DesignDocument> importLegacy(String id) async {
    if (!isSafeId(id)) {
      throw const FormatException('Invalid project identifier.');
    }
    await _tail;
    final file = File(
      '${_legacyProjects.path}${Platform.pathSeparator}$id.dsproject',
    );
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw const FormatException('Earlier project is not a regular file.');
    }
    if (await file.length() > maxProjectBytes) {
      throw const FormatException('Project exceeds the 32 MB limit.');
    }
    final bytes = await file.readAsBytes();
    final doc = DesignDocument.decode(bytes);
    if (doc.id != id) {
      throw const FormatException('Mismatched project identifier.');
    }
    return import(bytes);
  }

  /// Imports always receive a fresh id, so an existing project is never overwritten.
  Future<DesignDocument> import(Uint8List bytes) async {
    final doc = DesignDocument.decode(bytes)
        .copyWith(id: newId(), updatedAt: DateTime.now().toUtc());
    await save(doc);
    return doc;
  }

  Future<bool> readDarkMode() async {
    await _tail;
    final file = File('${root.path}${Platform.pathSeparator}settings.json');
    await recoverAtomicBackup(file);
    if (!await file.exists()) return false;
    try {
      if (await file.length() > 4096) return false;
      final json = jsonDecode(await file.readAsString());
      return json is Map && json['darkMode'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> writeDarkMode(bool enabled) => _enqueue(() async {
    final file = File('${root.path}${Platform.pathSeparator}settings.json');
    await replaceFileAtomically(
      file,
      utf8.encode(jsonEncode({'darkMode': enabled})),
    );
  });
}
