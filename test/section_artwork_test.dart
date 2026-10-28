import 'package:desksuite/app/section_artwork.dart';
import 'package:desksuite/app/theme.dart';
import 'package:desksuite/workspace/workspace_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('section artwork never replaces the approved app identity', () {
    expect(deskSuiteBrandAsset, 'assets/brand/desksuite-mark.png');
    expect(SectionArt.all, hasLength(6));
    expect(SectionArt.all.toSet(), hasLength(6));
    expect(SectionArt.all, isNot(contains(deskSuiteBrandAsset)));
    expect(artworkForSection(WorkspaceSection.scans), SectionArt.scan);
    expect(artworkForSection(WorkspaceSection.photos), SectionArt.photo);
    expect(artworkForSection(WorkspaceSection.text), SectionArt.text);
    expect(artworkForSection(WorkspaceSection.office), SectionArt.office);
    expect(artworkForSection(WorkspaceSection.design), SectionArt.design);
    expect(artworkForSection(WorkspaceSection.projects), SectionArt.projects);
    expect(artworkForSection(WorkspaceSection.workspace), isNull);
  });

  testWidgets('all six section illustrations are bundled PNG files', (
    tester,
  ) async {
    for (final asset in SectionArt.all) {
      final data = await rootBundle.load(asset);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      expect(bytes.take(8).toList(), [
        137,
        80,
        78,
        71,
        13,
        10,
        26,
        10,
      ], reason: asset);
    }
  });

  testWidgets('each drawer illustration belongs to its actual destination', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    WorkspaceSection? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 246,
            child: WorkspaceSidebar(
              section: WorkspaceSection.workspace,
              onNavigate: (value) => selected = value,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final expected = <WorkspaceSection, String>{
      WorkspaceSection.scans: SectionArt.scan,
      WorkspaceSection.photos: SectionArt.photo,
      WorkspaceSection.text: SectionArt.text,
      WorkspaceSection.office: SectionArt.office,
      WorkspaceSection.design: SectionArt.design,
      WorkspaceSection.projects: SectionArt.projects,
    };
    for (final item in expected.entries) {
      final art = find.byKey(ValueKey('nav-section-art-${item.key.name}'));
      expect(art, findsOneWidget, reason: item.key.name);
      expect(tester.widget<SectionArtwork>(art).asset, item.value);
      await tester.tap(art);
      await tester.pumpAndSettle();
      expect(selected, item.key);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'tool card remains tappable and fits large text on a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: deskTheme(Brightness.light),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 280,
                  child: WorkspaceToolCard(
                    section: WorkspaceSection.scans,
                    title: 'Scan documents',
                    description: 'Capture, clean and assemble pages.',
                    onNavigate: (section) =>
                        tapped = section == WorkspaceSection.scans,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SectionArtwork), findsOneWidget);
      expect(find.text('Scan documents'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Scan documents'));
      expect(tapped, isTrue);
    },
  );
}
