import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../app/section_artwork.dart';
import '../app/theme.dart';
import '../design/design_document.dart';
import '../design/template_catalog.dart';
import '../design/editor_screen.dart';
import '../document_scan/camera_gateway.dart';
import '../document_scan/scan_studio_page.dart';
import '../legacy_studios.dart' as legacy;
import '../ocr/text_extraction_page.dart';
import '../office/office_convert_page.dart';
import 'conversion_catalog.dart';
import 'conversion_catalog_page.dart';
import 'creative_studio_page.dart';
import 'file_gateway.dart';
import 'getting_started_page.dart';
import 'new_design_dialog.dart';
import 'project_repository.dart';
import 'workspace_widgets.dart';

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({
    super.key,
    required this.repository,
    required this.files,
    required this.dark,
    required this.onDarkChanged,
    this.camera,
    this.cameraRecovery,
  });
  final ProjectRepository repository;
  final FileGateway files;
  final bool dark;
  final Future<void> Function(bool) onDarkChanged;
  final CameraGateway? camera;
  final Future<CameraRecovery>? cameraRecovery;
  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  WorkspaceSection _section = WorkspaceSection.workspace;
  final _visited = <WorkspaceSection>{WorkspaceSection.workspace};
  ProjectList? _list;
  String? _listError;
  bool _loading = true;
  int _refreshVersion = 0;
  bool _showWelcome = false;
  Uint8List? _recoveredCapture;

  @override
  void initState() {
    super.initState();
    _refresh();
    _loadWelcome();
    widget.cameraRecovery?.then((result) {
      if (!mounted) return;
      if (result.bytes != null) {
        setState(() {
          _recoveredCapture = result.bytes;
          _section = WorkspaceSection.scans;
          _visited.add(WorkspaceSection.scans);
        });
      } else if (result.failed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _message(
            'The interrupted camera result could not be recovered. Check your camera app for a copy.',
          );
        });
      }
    });
  }

  Future<void> _loadWelcome() async {
    try {
      final seen = await widget.repository.readWelcomeSeen();
      if (mounted) setState(() => _showWelcome = !seen);
    } catch (_) {
      // The workspace still opens if the optional preference cannot be read.
    }
  }

  Future<void> _dismissWelcome({bool openGuide = false}) async {
    setState(() => _showWelcome = false);
    if (openGuide) _navigate(WorkspaceSection.guide);
    try {
      await widget.repository.writeWelcomeSeen();
    } catch (_) {
      _message(
        'Could not save the welcome preference; it may appear again next time.',
      );
    }
  }

  Future<void> _openEditableExample() async {
    try {
      final data = await rootBundle.load(
        'assets/samples/editable-example.dsdesign',
      );
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      final document = await widget.repository.import(bytes);
      if (mounted) await _openDocument(document);
    } catch (_) {
      _message(
        'Could not open the example design. Try again or check local storage.',
      );
    }
  }

  Future<void> _refresh() async {
    final version = ++_refreshVersion;
    try {
      final list = await widget.repository.list();
      if (mounted && version == _refreshVersion) {
        setState(() {
          _list = list;
          _listError = null;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted && version == _refreshVersion) {
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
    setState(() {
      _section = value;
      _visited.add(value);
    });
    if (value == WorkspaceSection.workspace ||
        value == WorkspaceSection.projects) {
      _refresh();
    }
  }

  Widget _lightStudio(Widget child) {
    final theme = deskTheme(Brightness.light);
    return Theme(
      data: theme,
      child: ColoredBox(color: theme.scaffoldBackgroundColor, child: child),
    );
  }

  Future<void> _openEarlierProject(legacy.Project project) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _lightStudio(legacy.EditorPage(project: project)),
      ),
    );
    await _refresh();
  }

  Future<void> _openEarlierStudio() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _lightStudio(
          Scaffold(
            appBar: AppBar(title: const Text('Earlier Creative Studio')),
            body: legacy.CreativePage(
              onCreate: () => _openEarlierProject(legacy.Project()),
              onOpen: _openEarlierProject,
            ),
          ),
        ),
      ),
    );
  }

  Widget _visitedStudio(WorkspaceSection section, Widget Function() create) =>
      _visited.contains(section)
      ? _lightStudio(create())
      : const SizedBox.shrink();

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
                      child: IndexedStack(
                        index: _section.index,
                        children: [
                          _workspace(),
                          _projectPage(),
                          _settings(),
                          _visited.contains(WorkspaceSection.design)
                              ? CreativeStudioPage(
                                  repository: widget.repository,
                                  files: widget.files,
                                  onEarlierEditor: _openEarlierStudio,
                                )
                              : const SizedBox.shrink(),
                          _visitedStudio(
                            WorkspaceSection.photos,
                            () => legacy.PhotoPage(files: widget.files),
                          ),
                          _visitedStudio(
                            WorkspaceSection.notes,
                            () => const legacy.NotesPage(),
                          ),
                          _visitedStudio(
                            WorkspaceSection.printing,
                            () => const legacy.PrintPage(),
                          ),
                          _visitedStudio(
                            WorkspaceSection.business,
                            () => legacy.BusinessPage(files: widget.files),
                          ),
                          _visited.contains(WorkspaceSection.scans)
                              ? ScanStudioPage(
                                  files: widget.files,
                                  camera: widget.camera,
                                  recoveredCapture: _recoveredCapture,
                                )
                              : const SizedBox.shrink(),
                          _visited.contains(WorkspaceSection.guide)
                              ? GettingStartedPage(
                                  onScan: () =>
                                      _navigate(WorkspaceSection.scans),
                                  onPhoto: () =>
                                      _navigate(WorkspaceSection.photos),
                                  onText: () =>
                                      _navigate(WorkspaceSection.text),
                                  onOffice: () =>
                                      _navigate(WorkspaceSection.office),
                                  onEditableExample: _openEditableExample,
                                )
                              : const SizedBox.shrink(),
                          _visited.contains(WorkspaceSection.conversions)
                              ? ConversionCatalogPage(
                                  onOpen: (target) =>
                                      _navigate(switch (target) {
                                        ConversionTarget.photos =>
                                          WorkspaceSection.photos,
                                        ConversionTarget.scans =>
                                          WorkspaceSection.scans,
                                        ConversionTarget.projects =>
                                          WorkspaceSection.projects,
                                        ConversionTarget.design =>
                                          WorkspaceSection.design,
                                        ConversionTarget.notes =>
                                          WorkspaceSection.notes,
                                        ConversionTarget.text =>
                                          WorkspaceSection.text,
                                        ConversionTarget.office =>
                                          WorkspaceSection.office,
                                      }),
                                )
                              : const SizedBox.shrink(),
                          _visited.contains(WorkspaceSection.text)
                              ? TextExtractionPage(files: widget.files)
                              : const SizedBox.shrink(),
                          _visited.contains(WorkspaceSection.office)
                              ? OfficeConvertPage(
                                  picker: widget.files is DocumentPicker
                                      ? widget.files as DocumentPicker
                                      : const _NoDocumentPicker(),
                                  files: widget.files,
                                )
                              : const SizedBox.shrink(),
                        ],
                      ),
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
          if (_section == WorkspaceSection.workspace) ...[
            const BrandMark(size: 32),
            const SizedBox(width: 10),
          ] else if (artworkForSection(_section) case final artwork?) ...[
            SectionArtwork(asset: artwork, size: 32),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              switch (_section) {
                WorkspaceSection.workspace => 'Workspace',
                WorkspaceSection.projects => 'Files & Projects',
                WorkspaceSection.settings => 'Settings',
                WorkspaceSection.design => 'Creative Studio',
                WorkspaceSection.photos => 'Photo Studio',
                WorkspaceSection.notes => 'Office Notes',
                WorkspaceSection.printing => 'Print Studio',
                WorkspaceSection.business => 'Business & POS',
                WorkspaceSection.scans => 'Scan & assemble',
                WorkspaceSection.guide => 'Getting started',
                WorkspaceSection.conversions => 'Conversion routes',
                WorkspaceSection.text => 'Text extraction',
                WorkspaceSection.office => 'Document converter',
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
        if (_showWelcome) ...[
          const SizedBox(height: 16),
          Card(
            key: const Key('welcome-introduction'),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const BrandMark(size: 48),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Welcome to DeskSuite',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create designs, prepare photos and assemble image PDFs locally. Explore examples or skip this introduction; no account is needed.',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton(
                        key: const Key('welcome-guide'),
                        onPressed: () => _dismissWelcome(openGuide: true),
                        child: const Text('Explore examples'),
                      ),
                      TextButton(
                        key: const Key('welcome-skip'),
                        onPressed: _dismissWelcome,
                        child: const Text('Skip for now'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 28),
        _heading('Your tools', 'Continue with a local workflow.'),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 820
                ? 3
                : constraints.maxWidth >= 520
                ? 2
                : 1;
            final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: width,
                  child: WorkspaceToolCard(
                    key: const Key('home-open-scan'),
                    artwork: SectionArt.scan,
                    title: 'Scan documents',
                    description: 'Capture, clean and assemble pages.',
                    onTap: () => _navigate(WorkspaceSection.scans),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: WorkspaceToolCard(
                    key: const Key('home-open-photo'),
                    artwork: SectionArt.photo,
                    title: 'Edit a photo',
                    description: 'Adjust and resize an image.',
                    onTap: () => _navigate(WorkspaceSection.photos),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: WorkspaceToolCard(
                    key: const Key('home-open-text'),
                    artwork: SectionArt.text,
                    title: 'Extract text',
                    description: 'Recognize and review words in an image.',
                    onTap: () => _navigate(WorkspaceSection.text),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: WorkspaceToolCard(
                    key: const Key('home-open-converter'),
                    artwork: SectionArt.office,
                    title: 'Convert file',
                    description: 'Read and convert supported document content.',
                    onTap: () => _navigate(WorkspaceSection.office),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: WorkspaceToolCard(
                    key: const Key('home-open-design'),
                    artwork: SectionArt.design,
                    title: 'Creative Studio',
                    description: 'Design an editable layout for print.',
                    onTap: () => _navigate(WorkspaceSection.design),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: WorkspaceToolCard(
                    key: const Key('home-open-projects'),
                    artwork: SectionArt.projects,
                    title: 'Files & Projects',
                    description: 'Open locally saved design projects.',
                    onTap: () => _navigate(WorkspaceSection.projects),
                  ),
                ),
              ],
            );
          },
        ),
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
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: 1.1,
                color: Theme.of(context).colorScheme.primary,
              ),
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
      key: const Key('projects-page'),
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
                subtitle: const Text(
                  'Theme for workspace and design. Other studios currently use light surfaces.',
                ),
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

/// Used when an injected gateway has no document picker (as in most widget
/// tests). Choosing a file then reports that the picker is unavailable instead
/// of silently doing nothing.
class _NoDocumentPicker implements DocumentPicker {
  const _NoDocumentPicker();
  @override
  Future<PickedDocument?> pickDocument() async => null;
}
