import 'package:flutter/material.dart';

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
  guide,
  conversions,
  // Appended last: IndexedStack children are indexed by this order.
  text,
  office,
  pdf,
}

class WorkspaceSidebar extends StatelessWidget {
  const WorkspaceSidebar({
    super.key,
    required this.section,
    required this.onNavigate,
  });
  final WorkspaceSection section;
  final ValueChanged<WorkspaceSection> onNavigate;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget item(IconData icon, String label, WorkspaceSection value) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        selected: section == value,
        selectedTileColor: scheme.primary.withValues(alpha: .09),
        selectedColor: scheme.primary,
        leading: Icon(icon, size: 21),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        onTap: () => onNavigate(value),
      ),
    );
    return Material(
      color: scheme.surface,
      child: ListView(
        children: [
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                BrandMark(),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DeskSuite',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.6,
                      ),
                    ),
                    Text(
                      'CREATIVE WORKSPACE',
                      style: TextStyle(fontSize: 9, letterSpacing: 1.05),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 35),
          _navLabel(context, 'WORKSPACE'),
          item(Icons.grid_view_rounded, 'Home', WorkspaceSection.workspace),
          item(
            Icons.school_outlined,
            'Getting started',
            WorkspaceSection.guide,
          ),
          item(
            Icons.folder_open_outlined,
            'Files & Projects',
            WorkspaceSection.projects,
          ),
          item(
            Icons.swap_horiz_rounded,
            'Conversion routes',
            WorkspaceSection.conversions,
          ),
          item(Icons.tune_rounded, 'Settings', WorkspaceSection.settings),
          const SizedBox(height: 24),
          _navLabel(context, 'STUDIOS'),
          item(
            Icons.palette_outlined,
            'Creative Studio',
            WorkspaceSection.design,
          ),
          item(Icons.photo_outlined, 'Photo Studio', WorkspaceSection.photos),
          item(
            Icons.document_scanner_outlined,
            'Scan & assemble',
            WorkspaceSection.scans,
          ),
          item(
            Icons.edit_note_outlined,
            'Office Notes',
            WorkspaceSection.notes,
          ),
          item(
            Icons.text_snippet_outlined,
            'Text extraction',
            WorkspaceSection.text,
          ),
          item(
            Icons.sync_alt_rounded,
            'Document converter',
            WorkspaceSection.office,
          ),
          item(
            Icons.picture_as_pdf_outlined,
            'PDF & Documents',
            WorkspaceSection.pdf,
          ),
          item(Icons.print_outlined, 'Print Studio', WorkspaceSection.printing),
          item(
            Icons.storefront_outlined,
            'Business & POS',
            WorkspaceSection.business,
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'CREATE. DESIGN. PRINT. MANAGE.',
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(letterSpacing: .8, color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navLabel(BuildContext context, String value) => Padding(
    padding: const EdgeInsets.fromLTRB(26, 0, 12, 8),
    child: Text(
      value,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        letterSpacing: 1.2,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

class WorkspaceWelcome extends StatelessWidget {
  const WorkspaceWelcome({
    super.key,
    required this.onCreate,
    required this.onImport,
  });
  final VoidCallback onCreate;
  final VoidCallback onImport;
  @override
  Widget build(BuildContext context) => Card(
    child: ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth > 620;
          return Padding(
            padding: EdgeInsets.all(wide ? 32 : 24),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'A WORKSPACE FOR YOUR IDEAS',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: accent,
                          letterSpacing: 1.3,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Make room\nfor good work.',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1.08,
                              letterSpacing: -1.2,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Create, edit and prepare a design for print—all in one place.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilledButton.icon(
                            key: const Key('new-design'),
                            onPressed: onCreate,
                            icon: const Icon(Icons.add, size: 19),
                            label: const Text('New design'),
                          ),
                          OutlinedButton(
                            onPressed: onImport,
                            child: const Text('Import project'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (wide) ...[
                  const SizedBox(width: 30),
                  SizedBox(
                    width: 210,
                    height: 180,
                    child: CustomPaint(painter: _WelcomeArt()),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    ),
  );
}

class _WelcomeArt extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(38, 18, 135, 150),
      const Radius.circular(3),
    );
    canvas.save();
    canvas.translate(8, 0);
    canvas.rotate(.075);
    canvas.drawRRect(rect, Paint()..color = const Color(0xffe7dfd4));
    canvas.restore();
    canvas.drawRRect(rect, Paint()..color = const Color(0xfff8f3eb));
    canvas.drawRRect(
      rect,
      Paint()
        ..color = const Color(0xffd5cbc0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawRect(
      const Rect.fromLTWH(52, 33, 107, 48),
      Paint()..color = const Color(0xffc77c60),
    );
    canvas.drawRect(
      const Rect.fromLTWH(52, 94, 64, 7),
      Paint()..color = const Color(0xff393630),
    );
    canvas.drawRect(
      const Rect.fromLTWH(52, 106, 84, 7),
      Paint()..color = const Color(0xff393630),
    );
    canvas.drawRect(
      const Rect.fromLTWH(52, 129, 48, 3),
      Paint()..color = const Color(0xffb5a89a),
    );
    canvas.drawRect(
      const Rect.fromLTWH(52, 137, 72, 3),
      Paint()..color = const Color(0xffb5a89a),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
