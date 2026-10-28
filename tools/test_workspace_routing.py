#!/usr/bin/env python3
"""Exercise the actual section/art routing switch with small UI stubs.

With an existing Dart SDK, run `python3 tools/test_workspace_routing.py`.
`--emit path.dart` writes the standalone harness without executing it. This is
not a Flutter, plugin, visual, accessibility or device integration test.
"""
import argparse
import re
import shutil
import subprocess
import tempfile
from pathlib import Path
root = Path(__file__).resolve().parents[1]
widgets = (root / 'lib/workspace/workspace_widgets.dart').read_text()
screen = (root / 'lib/workspace/workspace_screen.dart').read_text()
catalog = (root / 'lib/workspace/conversion_catalog.dart').read_text()
section_enum = re.search(r'enum WorkspaceSection\s*\{[^}]+\}', widgets, re.S).group()
target_enum = re.search(r'enum ConversionTarget\s*\{[^}]+\}', catalog, re.S).group()
art_file = (root / 'lib/app/section_artwork.dart').read_text()
art_constants = re.search(r'abstract final class SectionArt\s*\{[^}]+\}', art_file, re.S).group()
art_mapping = widgets[widgets.index('String? artworkForSection('):widgets.index('/// A labelled,')]
search_file = (root / 'lib/workspace/shortcut_search.dart').read_text()
search_logic = re.sub(r"^import [^\n]+\n", '', search_file, flags=re.M)
method = screen[screen.index('  Widget _visitedStudio('):screen.index('  @override\n  Widget build(BuildContext context) => LayoutBuilder(')]
for name in ('PhotoPage', 'NotesPage', 'PrintPage', 'BusinessPage'):
    method = method.replace('legacy.' + name, name)
stubs = r'''
typedef VoidCallback = void Function();
class Widget { const Widget(); }
class SizedBox extends Widget { const SizedBox.shrink(); }
class LightStudio extends Widget { const LightStudio(this.child); final Widget child; }
class HomePage extends Widget {}
class ProjectsPage extends Widget {}
class SettingsPage extends Widget {}
class FileGateway {}
abstract class DocumentPicker {}
class FilesAndPicker extends FileGateway implements DocumentPicker {}
class _NoDocumentPicker implements DocumentPicker { const _NoDocumentPicker(); }
class Params { FileGateway files = FileGateway(); Object repository = Object(); Object? camera; }
class CreativeStudioPage extends Widget {
  CreativeStudioPage({required Object repository, required FileGateway files, required Future<void> Function() onEarlierEditor});
}
class PhotoPage extends Widget { PhotoPage({required FileGateway files}); }
class NotesPage extends Widget { const NotesPage(); }
class PrintPage extends Widget { const PrintPage(); }
class BusinessPage extends Widget { BusinessPage({required FileGateway files}); }
class ScanStudioPage extends Widget { ScanStudioPage({required FileGateway files, Object? camera, Object? recoveredCapture}); }
class GettingStartedPage extends Widget {
  GettingStartedPage({required this.onScan, required this.onPhoto, required this.onText, required this.onOffice, required this.onPdf, required this.onEditableExample});
  final VoidCallback onScan, onPhoto, onText, onOffice, onPdf, onEditableExample;
}
class ConversionCatalogPage extends Widget {
  ConversionCatalogPage({required this.onOpen}); final void Function(ConversionTarget) onOpen;
}
class TextExtractionPage extends Widget { TextExtractionPage({required FileGateway files}); }
class OfficeConvertPage extends Widget {
  OfficeConvertPage({required this.picker, required this.files});
  final DocumentPicker picker; final FileGateway files;
}
class PdfStudioPage extends Widget {
  PdfStudioPage({required this.picker, required this.files});
  final DocumentPicker picker; final FileGateway files;
}
class Host {
  final _visited = <WorkspaceSection>{WorkspaceSection.workspace};
  final widget = Params();
  Object? _recoveredCapture;
  WorkspaceSection? opened;
  bool editedExample = false;
  Widget _workspace() => HomePage();
  Widget _projectPage() => ProjectsPage();
  Widget _settings() => SettingsPage();
  Widget _lightStudio(Widget page) => LightStudio(page);
  void _navigate(WorkspaceSection value, {bool closeDrawer = false}) { opened = value; }
  void _openEditableExample() { editedExample = true; }
  Future<void> _openEarlierStudio() async {}
'''
main = r'''
}
void check(bool value, String message) { if (!value) throw StateError(message); }
void main() {
  final assignments = <WorkspaceSection, String>{
    WorkspaceSection.scans: SectionArt.scan,
    WorkspaceSection.photos: SectionArt.photo,
    WorkspaceSection.text: SectionArt.text,
    WorkspaceSection.office: SectionArt.office,
    WorkspaceSection.design: SectionArt.design,
    WorkspaceSection.projects: SectionArt.projects,
  };
  for (final section in WorkspaceSection.values) {
    check(artworkForSection(section) == assignments[section], 'art ${section.name}');
  }
  check(homeShortcutSearchTerms.length == 7, 'home shortcut count');
  for (final section in homeShortcutSearchTerms.keys) {
    check(matchesHomeShortcut(section, '  '), 'empty search ${section.name}');
  }
  check(matchesHomeShortcut(WorkspaceSection.photos, 'PHOTO'), 'case-insensitive search');
  check(matchesHomeShortcut(WorkspaceSection.photos, 'resize  image'), 'multiword search');
  check(matchesHomeShortcut(WorkspaceSection.pdf, 'pdf split'), 'pdf search');
  check(!matchesHomeShortcut(WorkspaceSection.pdf, 'pdf spreadsheet'), 'all search words required');
  check(!matchesHomeShortcut(WorkspaceSection.settings, ''), 'non-shortcut excluded');
  check(!matchesHomeShortcut(WorkspaceSection.photos, 'nonsense'), 'no-result search');
  final h = Host();
  check(h._sectionPage(WorkspaceSection.workspace) is HomePage, 'home');
  check(h._sectionPage(WorkspaceSection.projects) is ProjectsPage, 'projects');
  check(h._sectionPage(WorkspaceSection.settings) is SettingsPage, 'settings');
  for (final section in WorkspaceSection.values.where((s) => ![WorkspaceSection.workspace, WorkspaceSection.projects, WorkspaceSection.settings].contains(s))) {
    check(h._sectionPage(section) is SizedBox, 'unvisited ${section.name}');
    h._visited.add(section);
  }
  check(h._sectionPage(WorkspaceSection.design) is CreativeStudioPage, 'design');
  check((h._sectionPage(WorkspaceSection.photos) as LightStudio).child is PhotoPage, 'photo');
  check((h._sectionPage(WorkspaceSection.notes) as LightStudio).child is NotesPage, 'notes');
  check((h._sectionPage(WorkspaceSection.printing) as LightStudio).child is PrintPage, 'printing');
  check((h._sectionPage(WorkspaceSection.business) as LightStudio).child is BusinessPage, 'business');
  check(h._sectionPage(WorkspaceSection.scans) is ScanStudioPage, 'scan');
  check(h._sectionPage(WorkspaceSection.text) is TextExtractionPage, 'text');
  check(h._sectionPage(WorkspaceSection.office) is OfficeConvertPage, 'office');
  check(h._sectionPage(WorkspaceSection.pdf) is PdfStudioPage, 'pdf');
  final fallbackOffice = h._sectionPage(WorkspaceSection.office) as OfficeConvertPage;
  check(fallbackOffice.picker is _NoDocumentPicker, 'office picker fallback');
  final fallbackPdf = h._sectionPage(WorkspaceSection.pdf) as PdfStudioPage;
  check(fallbackPdf.picker is _NoDocumentPicker, 'pdf picker fallback');
  h.widget.files = FilesAndPicker();
  final office = h._sectionPage(WorkspaceSection.office) as OfficeConvertPage;
  check(identical(office.picker, h.widget.files), 'office real picker forwarded');
  final pdf = h._sectionPage(WorkspaceSection.pdf) as PdfStudioPage;
  check(identical(pdf.picker, h.widget.files), 'pdf real picker forwarded');
  final guide = h._sectionPage(WorkspaceSection.guide) as GettingStartedPage;
  guide.onScan(); check(h.opened == WorkspaceSection.scans, 'guide scan');
  guide.onPhoto(); check(h.opened == WorkspaceSection.photos, 'guide photo');
  guide.onText(); check(h.opened == WorkspaceSection.text, 'guide text');
  guide.onOffice(); check(h.opened == WorkspaceSection.office, 'guide office');
  guide.onPdf(); check(h.opened == WorkspaceSection.pdf, 'guide pdf');
  guide.onEditableExample(); check(h.editedExample, 'guide editable');
  final catalog = h._sectionPage(WorkspaceSection.conversions) as ConversionCatalogPage;
  const targets = <ConversionTarget, WorkspaceSection>{
    ConversionTarget.photos: WorkspaceSection.photos,
    ConversionTarget.scans: WorkspaceSection.scans,
    ConversionTarget.projects: WorkspaceSection.projects,
    ConversionTarget.design: WorkspaceSection.design,
    ConversionTarget.notes: WorkspaceSection.notes,
    ConversionTarget.text: WorkspaceSection.text,
    ConversionTarget.office: WorkspaceSection.office,
    ConversionTarget.pdf: WorkspaceSection.pdf,
  };
  check(targets.length == ConversionTarget.values.length, 'conversion target coverage');
  for (final item in targets.entries) { catalog.onOpen(item.key); check(h.opened == item.value, 'conversion ${item.key.name}'); }
  print('Actual artwork, shortcut search and section switch: 14 pages, lazy states, 6 guide actions, 8 conversion actions and picker forwarding passed with UI stubs.');
}
'''
source = section_enum + '\n' + target_enum + '\n' + art_constants + '\n' + art_mapping + '\n' + search_logic + '\n' + stubs + method + main
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--emit', type=Path, help='write the standalone Dart harness without running it')
args = parser.parse_args()
if args.emit:
    args.emit.parent.mkdir(parents=True, exist_ok=True)
    args.emit.write_text(source)
    print(f'Wrote {args.emit}; run it with an existing Dart SDK.')
else:
    dart = shutil.which('dart')
    if not dart:
        parser.exit(1, 'No Dart SDK in PATH; use --emit to inspect the generated harness.\n')
    with tempfile.TemporaryDirectory(prefix='desksuite-route-smoke-') as temp:
        harness = Path(temp) / 'workspace_route_smoke.dart'
        harness.write_text(source)
        subprocess.run([dart, str(harness)], check=True)
