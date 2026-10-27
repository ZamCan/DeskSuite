import 'dart:math';

/// Identifiers are not file paths and contain only characters safe for filenames.
String newId() {
  final random = Random.secure().nextInt(0x7fffffff).toRadixString(36);
  return 'd_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}_$random';
}

bool isSafeId(String id) => RegExp(r'^[a-zA-Z0-9_-]{1,64}$').hasMatch(id);
