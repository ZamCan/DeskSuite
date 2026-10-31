import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../app/section_artwork.dart';
import '../app/theme.dart';
import 'project_repository.dart';

enum WorkspaceSection {
  workspace,
  projects,
  settings,
  design,
  photos,
  notes,
  printing,
  business,
  scans,
  conversions,
  // Appended last: IndexedStack children are indexed by this order.
  text,
  office,
  pdfStudio,
}

/// Section identities are decorative. The selected DS mark remains the app logo.
String? artworkForSection(WorkspaceSection section) => switch (section) {
  WorkspaceSection.scans => SectionArt.scan,
  WorkspaceSection.photos => SectionArt.photo,
  WorkspaceSection.text => SectionArt.text,
  WorkspaceSection.office => SectionArt.office,
  WorkspaceSection.design => SectionArt.design,
  WorkspaceSection.projects => SectionArt.projects,
  _ => null,
};

/// Number of task cards that can remain comfortably readable in one row.
/// Larger system text gets fewer columns rather than being clipped or scaled down.
int workspaceTaskColumnCount(double width, double textScale) {
  if (textScale > 1.8) return width >= 960 ? 2 : 1;
  if (textScale > 1.3) return width >= 640 ? 2 : 1;
  if (width >= 960) return 4;
  if (width >= 640) return 3;
  if (width >= 260) return 2;
  return 1;
}

/// Small, non-scrolling rows keep neighboring cards the same height while each
/// row can grow naturally for longer labels, translations or larger text.
class WorkspaceTaskGrid extends StatelessWidget {
  const WorkspaceTaskGrid({
    super.key,
    required this.columns,
    required this.cards,
  }) : assert(columns >= 1 && columns <= 4);

  final int columns;
  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    final rows = (cards.length + columns - 1) ~/ columns;
    return Column(
      children: [
        for (var row = 0; row < rows; row++) ...[
          if (row > 0) const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var column = 0; column < columns; column++) ...[
                  if (column > 0) const SizedBox(width: 12),
                  Expanded(
                    child: row * columns + column < cards.length
                        ? cards[row * columns + column]
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// A labelled, keyboard- and screen-reader-accessible route to a real tool.
class WorkspaceToolCard extends StatelessWidget {
  const WorkspaceToolCard({
    super.key,
    required this.section,
    required this.title,
    this.description = '',
    required this.onNavigate,
    this.fallbackIcon = Icons.grid_view_rounded,
  });

  /// The same section determines both the illustration and the destination.
  final WorkspaceSection section;
  final String title;
  final String description;
  final ValueChanged<WorkspaceSection> onNavigate;

  /// Used for real tools without one of the six approved section illustrations.
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final artwork = artworkForSection(section);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final tint = switch (section) {
      WorkspaceSection.scans => const Color(0xff5ecdbb),
      WorkspaceSection.pdfStudio => const Color(0xffef9a9b),
      WorkspaceSection.photos => const Color(0xffd9b29f),
      WorkspaceSection.text => const Color(0xffafa4e9),
      WorkspaceSection.office => const Color(0xff89c7a4),
      WorkspaceSection.design => const Color(0xffeab17c),
      WorkspaceSection.projects => const Color(0xffdbc88a),
      _ => scheme.primary,
    };
    final bottom = Color.lerp(scheme.surface, tint, dark ? .16 : .20)!;
    final border = Color.lerp(scheme.outline, tint, dark ? .30 : .62)!;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: dark ? .22 : .09),
            blurRadius: 24,
            spreadRadius: -3,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Material(
            color: Colors.transparent,
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.surface.withValues(alpha: .88),
                    bottom.withValues(alpha: .76),
                  ],
                ),
                border: Border.all(color: border.withValues(alpha: .82), width: 1.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => onNavigate(section),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 142),
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (artwork != null)
                              SectionArtwork(asset: artwork, size: 50)
                            else
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: scheme.primaryContainer.withValues(
                                    alpha: .8,
                                  ),
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                child: Icon(
                                  fallbackIcon,
                                  color: scheme.onPrimaryContainer,
                                ),
                              ),
                            const Spacer(),
                            Icon(
                              Icons.north_east_rounded,
                              size: 17,
                              color: scheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                        const SizedBox(height: 13),
                        Text(
                          title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.18,
                          ),
                        ),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(
                            description,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class WorkspaceSidebar extends StatelessWidget {
  const WorkspaceSidebar({super.key, required this.section, required this.onNavigate});
  final WorkspaceSection section;
  final ValueChanged<WorkspaceSection> onNavigate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget item(IconData icon, String label, WorkspaceSection value) {
      final selected = section == value;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
        child: ListTile(
          key: Key('nav-${value.name}'),
          dense: true,
          visualDensity: const VisualDensity(vertical: -1),
          minLeadingWidth: 30,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          selected: selected,
          selectedTileColor: scheme.primary.withValues(alpha: .10),
          selectedColor: scheme.primary,
          leading: Icon(icon, size: 21, color: selected ? scheme.primary : scheme.onSurfaceVariant),
          title: Text(label, style: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
          onTap: () => onNavigate(value),
        ),
      );
    }
    Widget label(String value) => Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 12, 6),
      child: Text(value, style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1.05, color: scheme.onSurfaceVariant)),
    );
    return Material(
      color: scheme.surface,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          const SizedBox(height: 22),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 22),
            child: Row(children: [
              BrandMark(size: 34),
              SizedBox(width: 11),
              Flexible(child: Text('DeskSuite', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -.55))),
            ]),
          ),
          label('WORKSPACE'),
          item(Icons.home_outlined, 'Home', WorkspaceSection.workspace),
          item(Icons.folder_outlined, 'Files', WorkspaceSection.projects),
          item(Icons.tune_rounded, 'Settings', WorkspaceSection.settings),
          label('STUDIOS'),
          item(Icons.photo_outlined, 'Photo Studio', WorkspaceSection.photos),
          item(Icons.document_scanner_outlined, 'Scanner', WorkspaceSection.scans),
          item(Icons.picture_as_pdf_outlined, 'PDF Studio', WorkspaceSection.pdfStudio),
          item(Icons.description_outlined, 'Documents', WorkspaceSection.office),
          item(Icons.text_snippet_outlined, 'Text extraction', WorkspaceSection.text),
          item(Icons.palette_outlined, 'Creative Studio', WorkspaceSection.design),
          label('MORE'),
          item(Icons.route_outlined, 'Conversion routes', WorkspaceSection.conversions),
          item(Icons.edit_note_outlined, 'Office Notes', WorkspaceSection.notes),
          item(Icons.print_outlined, 'Print Studio', WorkspaceSection.printing),
          item(Icons.storefront_outlined, 'Business & POS', WorkspaceSection.business),
        ],
      ),
    );
  }
}

class StarterCard extends StatelessWidget {
  const StarterCard({
    super.key,
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String eyebrow;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accent, size: 22),
                ),
                const Spacer(),
                const Icon(Icons.north_east, size: 16),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              eyebrow,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(letterSpacing: 1.1, color: accent),
            ),
            const SizedBox(height: 5),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class ProjectTile extends StatelessWidget {
  const ProjectTile({
    super.key,
    required this.item,
    required this.onOpen,
    required this.onDelete,
  });
  final ProjectSummary item;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) {
    final date = item.updatedAt.toLocal();
    return ListTile(
      key: Key('project-${item.id}'),
      onTap: onOpen,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      leading: Container(
        width: 48,
        height: 54,
        decoration: BoxDecoration(
          color: const Color(0xffeee6dd),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.description_outlined, color: accent),
      ),
      title: Text(
        item.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${item.widthMm.toStringAsFixed(0)} × ${item.heightMm.toStringAsFixed(0)} mm  ·  ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
      ),
      trailing: PopupMenuButton<String>(
        tooltip: 'Project options',
        onSelected: (value) {
          if (value == 'delete') onDelete();
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'delete', child: Text('Delete project')),
        ],
      ),
    );
  }
}
