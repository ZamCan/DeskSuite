import 'dart:io';

import 'package:flutter/material.dart';

import 'app/startup_view.dart';
import 'app/theme.dart';
import 'document_scan/camera_gateway.dart';
import 'core/suite_paths.dart';

import 'workspace/file_gateway.dart';
import 'workspace/project_repository.dart';
import 'workspace/workspace_screen.dart';

export 'legacy_studios.dart'
    show Project, EditorPage, PhotoPage, NotesPage, PrintPage, BusinessPage;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DeskSuiteApp());
}

class DeskSuiteApp extends StatefulWidget {
  const DeskSuiteApp({
    super.key,
    this.repository,
    this.fileGateway,
    this.cameraGateway,
  });
  final ProjectRepository? repository;
  final FileGateway? fileGateway;
  final CameraGateway? cameraGateway;
  @override
  State<DeskSuiteApp> createState() => _DeskSuiteAppState();
}

class _DeskSuiteAppState extends State<DeskSuiteApp> {
  late Future<ProjectRepository> _repository;
  late final CameraGateway? _camera;
  late final Future<CameraRecovery> _cameraRecovery;
  bool _dark = false;

  @override
  void initState() {
    super.initState();
    _camera =
        widget.cameraGateway ??
        (Platform.isAndroid ? AndroidCameraGateway() : null);
    _cameraRecovery = recoverCameraCapture(_camera);
    _repository = _initialize();
  }

  Future<ProjectRepository> _initialize() async {
    final repo =
        widget.repository ??
        ProjectRepository(await designRoot(), legacyRoot: await suiteRoot());
    final dark = await repo.readDarkMode();
    if (mounted) setState(() => _dark = dark);
    return repo;
  }

  Future<void> _setDark(ProjectRepository repo, bool value) async {
    await repo.writeDarkMode(value);
    if (mounted) setState(() => _dark = value);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'DeskSuite',
    debugShowCheckedModeBanner: false,
    theme: deskTheme(Brightness.light),
    darkTheme: deskTheme(Brightness.dark),
    themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
    home: FutureBuilder<ProjectRepository>(
      future: _repository,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.folder_off_outlined, size: 42),
                    const SizedBox(height: 16),
                    const Text('Local storage could not be opened.'),
                    const SizedBox(height: 8),
                    Text('${snapshot.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () =>
                          setState(() => _repository = _initialize()),
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const WorkspaceLoadingView();
        }
        final repo = snapshot.requireData;
        return WorkspaceScreen(
          repository: repo,
          files: widget.fileGateway ?? NativeFileGateway(),
          dark: _dark,
          onDarkChanged: (value) => _setDark(repo, value),
          camera: _camera,
          cameraRecovery: _cameraRecovery,
        );
      },
    ),
  );
}
