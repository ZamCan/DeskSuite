import 'package:flutter/material.dart';

import '../core/suite_paths.dart';
import '../design/design_document.dart';
import '../design/template_catalog.dart';
import '../design/editor_screen.dart';
import '../printing/print_gateway.dart';
import 'file_gateway.dart';
import 'new_design_dialog.dart';
import 'project_repository.dart';

/// Design browser with editable projects and non-destructive earlier imports.
class CreativeStudioPage extends StatefulWidget {
  const CreativeStudioPage({
    super.key,
    this.repository,
    this.files,
    this.printer,
    this.onEarlierEditor,
  });

  final ProjectRepository? repository;
  final FileGateway? files;
  final PrintGateway? printer;
  final Future<void> Function()? onEarlierEditor;

  @override
  State<CreativeStudioPage> createState() => _CreativeStudioPageState();
}

class _CreativeStudioPageState extends State<CreativeStudioPage> {
  ProjectRepository? _repository;
  late final FileGateway _files = widget.files ?? NativeFileGateway();
  ProjectList? _projects;
  ProjectList? _earlier;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      _repository =
          widget.repository ??
          ProjectRepository(await designRoot(), legacyRoot: await suiteRoot());
      await _refresh();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = '$error';
          _loading = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    try {
      final current = await _repository!.list();
      final earlier = await _repository!.listLegacy();
      if (!mounted) return;
      setState(() {
        _projects = current;
        _earlier = earlier;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = '$error';
          _loading = false;
        });
      }
    }
  }

  void _message(String value) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(value)));
    }
  }

  Future<void> _newDesign([
    DesignTemplate template = DesignTemplate.blank,
  ]) async {
    final doc = await showDialog<DesignDocument>(
      context: context,
      builder: (_) => NewDesignDialog(template: template),
    );
    if (doc == null || !mounted) return;
    try {
      await _repository!.save(doc);
      if (mounted) await _openDocument(doc);
    } catch (error) {
      _message('Could not create project: $error');
    }
  }

  Future<void> _openDocument(DesignDocument document) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EditorScreen(
          document: document,
          repository: _repository!,
          files: _files,
          printer: widget.printer,
        ),
      ),
    );
    await _refresh();
  }

  Future<void> _open(String id) async {
    try {
      final doc = await _repository!.load(id);
      if (mounted) await _openDocument(doc);
    } catch (error) {
      _message('Could not open project: $error');
    }
  }

  Future<void> _importFile() async {
    try {
      final bytes = await _files.pickProject();
      if (bytes == null) return;
      final doc = await _repository!.import(bytes);
      if (mounted) await _openDocument(doc);
    } catch (error) {
      _message('Could not import project: $error');
    }
  }

  Future<void> _importEarlier(ProjectSummary earlier) async {
    try {
      final doc = await _repository!.importLegacy(earlier.id);
      if (!mounted) return;
      _message('Opened a new copy. The earlier project is unchanged.');
      await _openDocument(doc);
    } catch (error) {
      _message('Could not import earlier project: $error');
    }
  }

  Future<void> _delete(ProjectSummary item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete project?'),
        content: Text(
          '“${item.name}” will be removed from this device. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete project'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repository!.delete(item.id);
      await _refresh();
    } catch (error) {
      _message('Could not delete project: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Could not load local designs.'),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  setState(() => _loading = true);
                  _initialize();
                },
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }
    final projects = _projects!;
    final earlier = _earlier!;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          Text(
            'Creative Studio',
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text('Editable designs, saved locally and prepared for print.'),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                key: const Key('new-design'),
                onPressed: () => _newDesign(),
                icon: const Icon(Icons.add),
                label: const Text('New design'),
              ),
              OutlinedButton.icon(
                key: const Key('import-project'),
                onPressed: _importFile,
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('Import project'),
              ),
              OutlinedButton.icon(
                onPressed: () => _newDesign(DesignTemplate.editorial),
                icon: const Icon(Icons.auto_awesome_mosaic_outlined),
                label: const Text('Poster template'),
              ),
            ],
          ),
          const SizedBox(height: 26),
          Text(
            'Your designs',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (projects.projects.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No designs yet. Create one to get started.'),
            )
          else
            ...projects.projects.map(
              (item) => Card(
                child: ListTile(
                  key: ValueKey('project-${item.id}'),
                  leading: const Icon(Icons.insert_drive_file_outlined),
                  title: Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${item.widthMm.toStringAsFixed(1)} × ${item.heightMm.toStringAsFixed(1)} mm · ${item.layerCount} objects',
                  ),
                  onTap: () => _open(item.id),
                  trailing: IconButton(
                    tooltip: 'Delete project',
                    onPressed: () => _delete(item),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
              ),
            ),
          if (projects.unreadableFiles.isNotEmpty)
            _unreadable(projects.unreadableFiles),
          const SizedBox(height: 22),
          Text(
            'Earlier designs',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Import a copy into the new editor; the original remains available.',
          ),
          if (earlier.projects.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No earlier designs found.'),
            )
          else
            ...earlier.projects.map(
              (item) => Card(
                child: ListTile(
                  key: ValueKey('legacy-${item.id}'),
                  title: Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${item.layerCount} objects · earlier project',
                  ),
                  trailing: const Icon(Icons.copy_outlined),
                  onTap: () => _importEarlier(item),
                ),
              ),
            ),
          if (earlier.unreadableFiles.isNotEmpty)
            _unreadable(earlier.unreadableFiles),
          if (widget.onEarlierEditor != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () async {
                  await widget.onEarlierEditor!();
                  if (mounted) await _refresh();
                },
                icon: const Icon(Icons.history),
                label: const Text('Open earlier editor'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _unreadable(List<String> files) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      '${files.length} project file(s) could not be opened: ${files.join(', ')}. The files were not changed.',
    ),
  );
}
