import 'package:desksuite/workspace/shortcut_search.dart';
import 'package:desksuite/workspace/workspace_widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('empty and whitespace queries show every real Home shortcut', () {
    expect(homeShortcutSearchTerms, hasLength(7));
    for (final section in homeShortcutSearchTerms.keys) {
      expect(matchesHomeShortcut(section, ''), isTrue);
      expect(matchesHomeShortcut(section, '  \t '), isTrue);
    }
    expect(matchesHomeShortcut(WorkspaceSection.settings, ''), isFalse);
  });

  test('search ignores case and requires every word', () {
    expect(matchesHomeShortcut(WorkspaceSection.photos, 'PHOTO'), isTrue);
    expect(
      matchesHomeShortcut(WorkspaceSection.photos, '  resize   image '),
      isTrue,
    );
    expect(
      matchesHomeShortcut(WorkspaceSection.pdfStudio, 'pdf combine'),
      isTrue,
    );
    expect(
      matchesHomeShortcut(WorkspaceSection.pdfStudio, 'pdf spreadsheet'),
      isFalse,
    );
    expect(matchesHomeShortcut(WorkspaceSection.office, 'WORD'), isTrue);
    expect(matchesHomeShortcut(WorkspaceSection.text, 'ocr'), isTrue);
  });

  test('unmatched and non-Home sections do not become shortcuts', () {
    expect(matchesHomeShortcut(WorkspaceSection.photos, 'nonsense'), isFalse);
    expect(matchesHomeShortcut(WorkspaceSection.business, 'business'), isFalse);
  });
}
