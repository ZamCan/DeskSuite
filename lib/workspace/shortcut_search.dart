import 'workspace_widgets.dart' show WorkspaceSection;

/// Search only the actual Home shortcuts; this is not a file or global search.
/// The keys match the sections used by their cards and navigation callbacks.
const homeShortcutSearchTerms = <WorkspaceSection, String>{
  WorkspaceSection.scans:
      'scan documents capture camera clean pages assemble image pdf',
  WorkspaceSection.pdfStudio:
      'pdf document pages review edit rotate combine inspect existing file',
  WorkspaceSection.photos: 'photo image picture edit resize clean jpeg png',
  WorkspaceSection.text: 'text ocr recognize words scan image extract',
  WorkspaceSection.office:
      'convert office file document word excel presentation',
  WorkspaceSection.design:
      'creative studio design template poster print layout',
  WorkspaceSection.projects: 'files projects saved local open design',
};

/// Each search word must occur in the section's local, case-insensitive terms.
/// Unknown sections are never presented as Home shortcuts.
bool matchesHomeShortcut(WorkspaceSection section, String query) {
  final terms = homeShortcutSearchTerms[section];
  if (terms == null) return false;
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) return true;
  return normalized.split(RegExp(r'\s+')).every(terms.contains);
}
