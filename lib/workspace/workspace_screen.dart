import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../design/design_document.dart';
import '../design/editor_screen.dart';
import 'file_gateway.dart';
import 'new_design_dialog.dart';
import 'external_file_opener.dart';
import 'project_repository.dart';
import 'workspace_widgets.dart';

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({
    super.key,
    required this.repository,
    required this.files,
    required this.dark,
    required this.onDarkChanged,
  });
  final ProjectRepository repository;
  final FileGateway files;
  final bool dark;
  final Future<void> Function(bool) onDarkChanged;
  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  WorkspaceSection _section = WorkspaceSection.workspace;
  ProjectList? _list;
  String? _listError;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final list = await widget.repository.list();
      if (mounted) {
        setState(() {
          _list = list;
          _listError = null;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _listError = '$error';
          _loading = false;
        });
      }
    }
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
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
      await widget.repository.save(doc);
      if (!mounted) return;
      await _openDocument(doc);
    } catch (error) {
      _message('Could not create project: $error');
    }
  }

  Future<void> _openDocument(DesignDocument doc) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EditorScreen(
          document: doc,
          repository: widget.repository,
          files: widget.files,
        ),
      ),
    );
    await _refresh();
  }

  Future<void> _open(String id) async {
    try {
      final doc = await widget.repository.load(id);
      if (!mounted) return;
      await _openDocument(doc);
    } catch (error) {
      _message('Could not open this project: $error');
    }
  }

  Future<void> _import() async {
    try {
      final bytes = await widget.files.pickProject();
      if (bytes == null) return;
      final doc = await widget.repository.import(bytes);
      if (!mounted) return;
      await _openDocument(doc);
    } catch (error) {
      _message('Could not import project: $error');
    }
  }

  Future<void> _openExternalFile() async {
    try {
      final opened = await ExternalFileOpener().pickAndOpen();
      if (opened) {
        _message(
          'The original file was handed to a compatible installed app. DeskSuite did not modify it.',
        );
      }
    } catch (error) {
      _message('Could not open this file in another app: $error');
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
      await widget.repository.delete(item.id);
      await _refresh();
    } catch (error) {
      _message('Could not delete project: $error');
    }
  }

  void _navigate(WorkspaceSection value, {bool closeDrawer = false}) {
    if (closeDrawer) Navigator.of(context).pop();
    setState(() => _section = value);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 850;
      final sidebar = WorkspaceSidebar(
        section: _section,
        onNavigate: (s) => _navigate(s, closeDrawer: !wide),
      );
      return Scaffold(
        drawer: wide ? null : Drawer(child: SafeArea(child: sidebar)),
        body: SafeArea(
          child: Row(
            children: [
              if (wide) SizedBox(width: 246, child: sidebar),
              if (wide) const VerticalDivider(width: 1),
              Expanded(
                child: Column(
                  children: [
                    _topBar(wide),
                    const Divider(height: 1),
                    Expanded(
                      child: switch (_section) {
                        WorkspaceSection.workspace => _workspace(),
                        WorkspaceSection.projects => _projectPage(),
                        WorkspaceSection.settings => _settings(),
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _topBar(bool wide) => SizedBox(
    height: 68,
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: wide ? 30 : 14),
      child: Row(
        children: [
          if (!wide)
            Builder(
              builder: (context) => IconButton(
                tooltip: 'Open navigation',
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: const Icon(Icons.menu_rounded),
              ),
            ),
          if (!wide) const SizedBox(width: 6),
          Expanded(
            child: Text(
              switch (_section) {
                WorkspaceSection.workspace => 'Workspace',
                WorkspaceSection.projects => 'Files & Projects',
                WorkspaceSection.settings => 'Settings',
              },
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (wide)
            Text(
              'LOCAL WORKSPACE',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: 1.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(width: 12),
          const Icon(Icons.lock_outline_rounded, size: 17),
          const SizedBox(width: 6),
          Text('Offline', style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    ),
  );

  Widget _workspace() => _scrolling(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WorkspaceWelcome(onCreate: () => _newDesign(), onImport: _import),
        const SizedBox(height: 34),
        Row(
          children: [
            Expanded(
              child: _heading(
                'Start creating',
                'Pick up a blank canvas or a ready-to-edit layout.',
              ),
            ),
            Text(
              '01 / CREATE',
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(letterSpacing: 1.1, color: accent),
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth >= 700
                ? (constraints.maxWidth - 24) / 3
                : constraints.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: width,
                  child: StarterCard(
                    icon: Icons.add_box_outlined,
                    eyebrow: 'START FRESH',
                    title: 'Blank design',
                    subtitle: 'Choose your own canvas',
                    onTap: () => _newDesign(),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: StarterCard(
                    icon: Icons.auto_awesome_mosaic_outlined,
                    eyebrow: 'LOCAL TEMPLATE',
                    title: 'Editorial poster',
                    subtitle: 'A simple editable layout',
                    onTap: () => _newDesign(DesignTemplate.editorial),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: StarterCard(
                    icon: Icons.file_open_outlined,
                    eyebrow: 'YOUR FILES',
                    title: 'Import a project',
                    subtitle: 'Open a .dsdesign file',
                    onTap: _import,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: StarterCard(
                    icon: Icons.open_in_new_rounded,
                    eyebrow: 'OPEN EXTERNALLY',
                    title: 'Open with an app',
                    subtitle: 'PDF, Word, Excel, PowerPoint and images',
                    onTap: _openExternalFile,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 38),
        Row(
          children: [
            Expanded(
              child: _heading(
                'Recent projects',
                'Your work stays on this device.',
              ),
            ),
            TextButton(
              onPressed: () => _navigate(WorkspaceSection.projects),
              child: const Text('View all'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _projectList(limit: 4),
        const SizedBox(height: 26),
      ],
    ),
  );

  Widget _projectPage() => _scrolling(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _heading(
                'Files & Projects',
                'Designs saved locally on this device.',
              ),
            ),
            const SizedBox(width: 12),
            IconButton.outlined(
              tooltip: 'Import project',
              onPressed: _import,
              icon: const Icon(Icons.file_open_outlined),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _projectList(),
      ],
    ),
  );

  Widget _settings() => _scrolling(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading('Settings', 'A quiet workspace, configured for you.'),
        const SizedBox(height: 24),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Dark appearance'),
                subtitle: const Text('Change the workspace theme.'),
                value: widget.dark,
                onChanged: (value) async {
                  try {
                    await widget.onDarkChanged(value);
                  } catch (error) {
                    _message('Could not save setting: $error');
                  }
                },
              ),
              const Divider(height: 1),
              const ListTile(
                leading: Icon(Icons.folder_outlined),
                title: Text('Local project storage'),
                subtitle: Text(
                  'Projects are stored in the app’s private files. Export a project copy before uninstalling.',
                ),
              ),
              const Divider(height: 1),
              const ListTile(
                leading: Icon(Icons.privacy_tip_outlined),
                title: Text('Privacy'),
                subtitle: Text(
                  'No account or analytics. Project files are not encrypted by DeskSuite.',
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Open-source licences'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'DeskSuite',
                  applicationVersion: '0.1.0',
                  applicationIcon: const BrandMark(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('DeskSuite · 0.1.0', style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );

  Widget _heading(String title, String subtitle) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -.4),
      ),
      const SizedBox(height: 4),
      Text(
        subtitle,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ],
  );

  Widget _scrolling({required Widget child}) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 30, 24, 40),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1050),
        child: child,
      ),
    ),
  );

  Widget _projectList({int? limit}) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_listError != null) {
      return Card(
        child: ListTile(
          title: const Text('Projects could not be loaded'),
          subtitle: Text(_listError!),
          trailing: IconButton(
            tooltip: 'Retry',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ),
      );
    }
    final list = _list ?? const ProjectList([], []);
    final items = limit == null
        ? list.projects
        : list.projects.take(limit).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (list.unreadableFiles.isNotEmpty)
          Card(
            child: ListTile(
              leading: const Icon(Icons.warning_amber_rounded),
              title: Text(
                '${list.unreadableFiles.length} project file(s) could not be opened',
              ),
              subtitle: Text(
                'Files were left untouched: ${list.unreadableFiles.join(', ')}',
              ),
            ),
          ),
        if (items.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.note_add_outlined),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'A fresh start',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 4),
                        Text('Create your first design to see it here.'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Card(
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  ProjectTile(
                    item: items[i],
                    onOpen: () => _open(items[i].id),
                    onDelete: () => _delete(items[i]),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
