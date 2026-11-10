import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  Widget _topBar(bool wide) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final art = artworkForSection(_section);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          color: Color.lerp(scheme.surface, theme.scaffoldBackgroundColor, .45),
          border: Border(bottom: BorderSide(color: theme.dividerColor)),
        ),
        padding: EdgeInsets.only(left: wide ? 26 : 6, right: wide ? 24 : 12),
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
            if (!wide) const SizedBox(width: 2),
            if (art != null) ...[
              SectionArtwork(
                key: ValueKey('section-header-art-${_section.name}'),
                asset: art,
                size: 30,
              ),
              const SizedBox(width: 12),
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
                style: wide
                    ? theme.textTheme.titleLarge
                    : theme.textTheme.titleMedium,
              ),
            ),
            if (wide) ...[const SizedBox(width: 12), _localPill()],
          ],
        ),
      ),
    );
  }

  /// A quiet reminder of the product's actual contract: work stays on the
  /// device until the user exports or shares it.
  Widget _localPill() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(
          alpha: dark ? .55 : .5,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 13,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            'On device',
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: .3,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _workspace() {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    final hasQuery = _shortcutQuery.trim().isNotEmpty;

    return _scrolling(
      glassBackdrop: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            greeting,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 5),
          _heading('Your workspace', 'Create, scan, organise and produce.'),
          if (!hasQuery) ...[const SizedBox(height: 22), _premiumScanBanner()],
          const SizedBox(height: 20),
          TextField(
            key: const Key('home-shortcut-search'),
            controller: _shortcutSearch,
            textInputAction: TextInputAction.search,
            onChanged: (value) => setState(() => _shortcutQuery = value),
            onSubmitted: (_) => FocusScope.of(context).unfocus(),
            decoration: InputDecoration(
              hintText: 'Search tools and workflows',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _shortcutQuery.isEmpty
                  ? null
                  : IconButton(
                      key: const Key('home-clear-shortcut-search'),
                      tooltip: 'Clear search',
                      onPressed: () => setState(() {
                        _shortcutSearch.clear();
                        _shortcutQuery = '';
                      }),
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          if (hasQuery) ...[
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
          const SizedBox(height: 22),
          Text(
            hasQuery ? 'SEARCH RESULTS' : 'STUDIOS',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              letterSpacing: 1.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          if (homeShortcutSearchTerms.keys.any(
            (section) => matchesHomeShortcut(section, _shortcutQuery),
          ))
            LayoutBuilder(
              builder: (context, constraints) {
                final textScale =
                    MediaQuery.textScalerOf(context).scale(16) / 16;
                final columns = workspaceTaskColumnCount(
                  constraints.maxWidth,
                  textScale,
                );
                final cards = <Widget>[
                  if (matchesHomeShortcut(
                    WorkspaceSection.scans,
                    _shortcutQuery,
                  ))
                    WorkspaceToolCard(
                      key: const Key('home-open-scan'),
                      section: WorkspaceSection.scans,
                      title: 'Scanner',
                      description: 'Capture clean documents',
                      onNavigate: _navigate,
                    ),
                  if (matchesHomeShortcut(
                    WorkspaceSection.pdfStudio,
                    _shortcutQuery,
                  ))
                    WorkspaceToolCard(
                      key: const Key('home-open-pdf'),
                      section: WorkspaceSection.pdfStudio,
                      title: 'PDF Studio',
                      description: 'Review, combine and inspect',
                      fallbackIcon: Icons.picture_as_pdf_outlined,
                      onNavigate: _navigate,
                    ),
                  if (matchesHomeShortcut(
                    WorkspaceSection.photos,
                    _shortcutQuery,
                  ))
                    WorkspaceToolCard(
                      key: const Key('home-open-photo'),
                      section: WorkspaceSection.photos,
                      title: 'Photo Studio',
                      description: 'Edit and prepare images',
                      onNavigate: _navigate,
                    ),
                  if (matchesHomeShortcut(
                    WorkspaceSection.text,
                    _shortcutQuery,
                  ))
                    WorkspaceToolCard(
                      key: const Key('home-open-text'),
                      section: WorkspaceSection.text,
                      title: 'Text extraction',
                      description: 'Recognise text from images',
                      onNavigate: _navigate,
                    ),
                  if (matchesHomeShortcut(
                    WorkspaceSection.office,
                    _shortcutQuery,
                  ))
                    WorkspaceToolCard(
                      key: const Key('home-open-converter'),
                      section: WorkspaceSection.office,
                      title: 'Documents',
                      description: 'Convert office formats',
                      onNavigate: _navigate,
                    ),
                  if (matchesHomeShortcut(
                    WorkspaceSection.design,
                    _shortcutQuery,
                  ))
                    WorkspaceToolCard(
                      key: const Key('home-open-design'),
                      section: WorkspaceSection.design,
                      title: 'Creative Studio',
                      description: 'Design posters and layouts',
                      onNavigate: _navigate,
                    ),
                ];
                return WorkspaceTaskGrid(columns: columns, cards: cards);
              },
            )
          else
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                  'No matching workspaces. Try another search.',
                  key: Key('home-shortcut-empty'),
                ),
              ),
            ),
          const SizedBox(height: 26),
        ],
      ),
    );
  }

  Widget _premiumScanBanner() {
    final text = Theme.of(context).textTheme;
    return Container(
      key: const Key('home-premium-scan-banner'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xff231c14),
            Color.lerp(const Color(0xff231c14), clay, .38)!,
          ],
        ),
        borderRadius: BorderRadius.circular(duneCardRadius),
        border: Border.all(
          color: Color.lerp(clay, accent, .45)!.withValues(alpha: .55),
        ),
        boxShadow: duneShadow(Theme.of(context).brightness, blur: 26, y: 11),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'READY WHEN YOU ARE',
                  style: text.labelSmall?.copyWith(
                    color: const Color(0xffe8b294),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  'Scan a page',
                  style: text.headlineSmall?.copyWith(color: paper),
                ),
                const SizedBox(height: 5),
                Text(
                  'Capture, clean and save paper as a document.',
                  style: text.bodySmall?.copyWith(
                    color: paper.withValues(alpha: .78),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 15),
                FilledButton.icon(
                  key: const Key('home-premium-scan-action'),
                  onPressed: () => _navigate(WorkspaceSection.scans),
                  style: FilledButton.styleFrom(
                    backgroundColor: paper,
                    foregroundColor: ink,
                    minimumSize: const Size(48, 44),
                  ),
                  icon: const Icon(Icons.document_scanner_outlined, size: 19),
                  label: const Text('Start scanning'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: paper.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(19),
              border: Border.all(color: paper.withValues(alpha: .18)),
            ),
            child: const Icon(
              Icons.document_scanner_rounded,
              color: Color(0xffeab99b),
              size: 34,
            ),
          ),
        ],
      ),
    );
  }

  Widget _projectPage() => _scrolling(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _heading('Files', 'Designs saved locally on this device.'),
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
      Text(title, style: Theme.of(context).textTheme.headlineSmall),
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
    // Dune daylight: sun-bleached sand at the top, paper through the middle
    // and a faint phosphate wash underneath. Mixed from explicit tokens so the
    // backdrop cannot inherit a cold seeded container colour.
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(base, sandDeep, dark ? .40 : .55)!,
            base,
            Color.lerp(base, phosphateWash, dark ? .24 : .50)!,
          ],
          stops: const [0, .52, 1],
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
