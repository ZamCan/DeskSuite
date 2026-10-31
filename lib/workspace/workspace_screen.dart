import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../app/section_artwork.dart';
import '../app/theme.dart';
import '../design/design_document.dart';
import '../design/editor_screen.dart';
import '../document_scan/camera_gateway.dart';
import '../document_scan/scan_studio_page.dart';
import '../legacy_studios.dart' as legacy;
import '../ocr/text_extraction_page.dart';
import '../office/office_convert_page.dart';
import '../pdf/pdf_studio_page.dart';
import 'conversion_catalog.dart';
import 'conversion_catalog_page.dart';
import 'creative_studio_page.dart';
import 'file_gateway.dart';
import 'project_repository.dart';
import 'shortcut_search.dart';
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
  Uint8List? _recoveredCapture;
  final _shortcutSearch = TextEditingController();
  String _shortcutQuery = '';

  @override
  void initState() {
    super.initState();
    _refresh();
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
            'The interrupted camera capture could not be recovered. Its private cache may still contain a copy.',
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _shortcutSearch.dispose();
    super.dispose();
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

  /// Each enum value resolves to its own real page, independent of enum order.
  /// The exhaustive switch makes an unmapped new section a compile-time error.
  Widget _sectionPage(WorkspaceSection section) => switch (section) {
    WorkspaceSection.workspace => _workspace(),
    WorkspaceSection.projects => _projectPage(),
    WorkspaceSection.settings => _settings(),
    WorkspaceSection.design =>
      _visited.contains(section)
          ? CreativeStudioPage(
              repository: widget.repository,
              files: widget.files,
              onEarlierEditor: _openEarlierStudio,
            )
          : const SizedBox.shrink(),
    WorkspaceSection.photos => _visitedStudio(
      section,
      () => legacy.PhotoPage(files: widget.files),
    ),
    WorkspaceSection.notes => _visitedStudio(
      section,
      () => const legacy.NotesPage(),
    ),
    WorkspaceSection.printing => _visitedStudio(
      section,
      () => const legacy.PrintPage(),
    ),
    WorkspaceSection.business => _visitedStudio(
      section,
      () => legacy.BusinessPage(files: widget.files),
    ),
    WorkspaceSection.scans =>
      _visited.contains(section)
          ? ScanStudioPage(
              files: widget.files,
              camera: widget.camera,
              isActive: _section == WorkspaceSection.scans,
              recoveredCapture: _recoveredCapture,
            )
          : const SizedBox.shrink(),
    WorkspaceSection.conversions =>
      _visited.contains(section)
          ? ConversionCatalogPage(
              onOpen: (target) => _navigate(switch (target) {
                ConversionTarget.photos => WorkspaceSection.photos,
                ConversionTarget.scans => WorkspaceSection.scans,
                ConversionTarget.projects => WorkspaceSection.projects,
                ConversionTarget.design => WorkspaceSection.design,
                ConversionTarget.notes => WorkspaceSection.notes,
                ConversionTarget.text => WorkspaceSection.text,
                ConversionTarget.office => WorkspaceSection.office,
                ConversionTarget.pdfStudio => WorkspaceSection.pdfStudio,
              }),
            )
          : const SizedBox.shrink(),
    WorkspaceSection.text =>
      _visited.contains(section)
          ? TextExtractionPage(files: widget.files)
          : const SizedBox.shrink(),
    WorkspaceSection.office =>
      _visited.contains(section)
          ? OfficeConvertPage(
              picker: widget.files is DocumentPicker
                  ? widget.files as DocumentPicker
                  : const _NoDocumentPicker(),
              files: widget.files,
            )
          : const SizedBox.shrink(),
    WorkspaceSection.pdfStudio =>
      _visited.contains(section)
          ? PdfStudioPage(
              picker: widget.files is DocumentPicker
                  ? widget.files as DocumentPicker
                  : const _NoDocumentPicker(),
              files: widget.files,
            )
          : const SizedBox.shrink(),
  };

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
                          for (final section in WorkspaceSection.values)
                            KeyedSubtree(
                              key: ValueKey('workspace-page-${section.name}'),
                              child: _sectionPage(section),
                            ),
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
          if (_section != WorkspaceSection.workspace &&
              artworkForSection(_section) != null) ...[
            SectionArtwork(
              key: ValueKey('section-header-art-${_section.name}'),
              asset: artworkForSection(_section)!,
              size: 32,
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              switch (_section) {
                WorkspaceSection.workspace => 'Home',
                WorkspaceSection.projects => 'Files',
                WorkspaceSection.settings => 'Settings',
                WorkspaceSection.design => 'Creative Studio',
                WorkspaceSection.photos => 'Photo Studio',
                WorkspaceSection.notes => 'Office Notes',
                WorkspaceSection.printing => 'Print Studio',
                WorkspaceSection.business => 'Business & POS',
                WorkspaceSection.scans => 'Scanner',
                WorkspaceSection.conversions => 'Conversion routes',
                WorkspaceSection.text => 'Text extraction',
                WorkspaceSection.office => 'Documents',
                WorkspaceSection.pdfStudio => 'PDF Studio',
              },
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (wide) const SizedBox(width: 12),
        ],
      ),
    ),
  );

  Widget _workspace() => _scrolling(
    glassBackdrop: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading('Workspaces', ''),
        const SizedBox(height: 16),
        TextField(
          key: const Key('home-shortcut-search'),
          controller: _shortcutSearch,
          textInputAction: TextInputAction.search,
          onChanged: (value) => setState(() => _shortcutQuery = value),
          onSubmitted: (_) => FocusScope.of(context).unfocus(),
          decoration: InputDecoration(
            hintText: 'Search workspaces',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _shortcutQuery.isEmpty ? null : IconButton(
              key: const Key('home-clear-shortcut-search'),
              tooltip: 'Clear search',
              onPressed: () => setState(() {
                _shortcutSearch.clear();
                _shortcutQuery = '';
              }),
              icon: const Icon(Icons.close),
            ),
          ),
        ),
        if (_shortcutQuery.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Text(
              '${homeShortcutSearchTerms.keys.where((section) => matchesHomeShortcut(section, _shortcutQuery)).length} of ${homeShortcutSearchTerms.length} workspaces',
              key: const Key('home-shortcut-result-count'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
        const SizedBox(height: 18),
        if (homeShortcutSearchTerms.keys.any((section) => matchesHomeShortcut(section, _shortcutQuery)))
          LayoutBuilder(
            builder: (context, constraints) {
              final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
              final columns = workspaceTaskColumnCount(constraints.maxWidth, textScale);
              final cards = <Widget>[
                if (matchesHomeShortcut(WorkspaceSection.scans, _shortcutQuery))
                  WorkspaceToolCard(key: const Key('home-open-scan'), section: WorkspaceSection.scans, title: 'Scanner', onNavigate: _navigate),
                if (matchesHomeShortcut(WorkspaceSection.pdfStudio, _shortcutQuery))
                  WorkspaceToolCard(key: const Key('home-open-pdf'), section: WorkspaceSection.pdfStudio, title: 'PDF Studio', fallbackIcon: Icons.picture_as_pdf_outlined, onNavigate: _navigate),
                if (matchesHomeShortcut(WorkspaceSection.photos, _shortcutQuery))
                  WorkspaceToolCard(key: const Key('home-open-photo'), section: WorkspaceSection.photos, title: 'Photo Studio', onNavigate: _navigate),
                if (matchesHomeShortcut(WorkspaceSection.text, _shortcutQuery))
                  WorkspaceToolCard(key: const Key('home-open-text'), section: WorkspaceSection.text, title: 'Text extraction', onNavigate: _navigate),
                if (matchesHomeShortcut(WorkspaceSection.office, _shortcutQuery))
                  WorkspaceToolCard(key: const Key('home-open-converter'), section: WorkspaceSection.office, title: 'Documents', onNavigate: _navigate),
                if (matchesHomeShortcut(WorkspaceSection.design, _shortcutQuery))
                  WorkspaceToolCard(key: const Key('home-open-design'), section: WorkspaceSection.design, title: 'Creative Studio', onNavigate: _navigate),
              ];
              return WorkspaceTaskGrid(columns: columns, cards: cards);
            },
          )
        else
          const Card(child: Padding(
            padding: EdgeInsets.all(18),
            child: Text('No matching workspaces. Try another search.', key: Key('home-shortcut-empty')),
          )),
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
                'Files',
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
                title: Text('Project storage'),
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
            ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -.55),
      ),
      if (subtitle.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    ],
  );

  Widget _scrolling({required Widget child, bool glassBackdrop = false}) {
    final content = SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1050),
          child: child,
        ),
      ),
    );
    if (!glassBackdrop) return content;
    final theme = Theme.of(context);
    final base = theme.scaffoldBackgroundColor;
    final dark = theme.brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(
              base,
              theme.colorScheme.primaryContainer,
              dark ? .18 : .28,
            )!,
            base,
            Color.lerp(
              base,
              theme.colorScheme.tertiaryContainer,
              dark ? .10 : .16,
            )!,
          ],
        ),
      ),
      child: content,
    );
  }

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
