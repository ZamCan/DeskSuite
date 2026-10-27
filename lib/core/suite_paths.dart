import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Existing app-support root for the earlier prototype, notes and catalogue.
Future<Directory> suiteRoot() async {
  final support = await getApplicationSupportDirectory();
  final root = Directory('${support.path}${Platform.pathSeparator}desksuite');
  if (!await root.exists()) await root.create(recursive: true);
  return root;
}

/// Preserve the modular main branch's existing document/project directory.
Future<Directory> designRoot() async {
  final documents = await getApplicationDocumentsDirectory();
  return Directory('${documents.path}${Platform.pathSeparator}DeskSuite');
}
