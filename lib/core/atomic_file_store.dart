import 'dart:io';

import 'ids.dart';

/// Same-directory replacement. A Windows backup is kept until the new file
/// exists and can be recovered after an interrupted replacement.
Future<void> replaceFileAtomically(File target, List<int> data) async {
  await target.parent.create(recursive: true);
  final temporary = File('${target.path}.${newId()}.tmp');
  final backup = File('${target.path}.bak');
  try {
    await temporary.writeAsBytes(data, flush: true);
    if (Platform.isWindows && await target.exists()) {
      if (await backup.exists()) await backup.delete();
      await target.rename(backup.path);
      try {
        await temporary.rename(target.path);
        await backup.delete();
      } catch (_) {
        if (!await target.exists() && await backup.exists()) {
          await backup.rename(target.path);
        }
        rethrow;
      }
    } else {
      await temporary.rename(target.path);
    }
  } finally {
    if (await temporary.exists()) await temporary.delete();
  }
}

Future<void> recoverAtomicBackup(File target) async {
  final backup = File('${target.path}.bak');
  if (!await target.exists() && await backup.exists()) {
    await backup.rename(target.path);
  }
}
