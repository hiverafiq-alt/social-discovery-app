import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_discovery/app/app.dart';

void main() {
  testWidgets(
    'browser preview opens discovery and supports invitation and accepted chat',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const ProviderScope(child: SocialDiscoveryApp()));
      await tester.pumpAndSettle();
      expect(find.text('Studio preview · Sample profiles'), findsOneWidget);
      expect(find.text('Maya, 27'), findsOneWidget);
      await tester.tap(find.text('Interested'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send a free invitation'));
      await tester.pumpAndSettle();
      expect(find.text('Alex, 29'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Invitations'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Accept'));
      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Open conversation'));
      await tester.tap(find.text('Open conversation'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'Hello from the browser preview',
      );
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
      expect(find.text('Hello from the browser preview'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'browser preview explains native camera limitation without requesting permissions',
    (tester) async {
      await tester.pumpWidget(const ProviderScope(child: SocialDiscoveryApp()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('You'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Open camera studio'));
      await tester.tap(find.text('Open camera studio'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('does not record or upload video'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('browser sample request never needs a real evidence file', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const ProviderScope(child: SocialDiscoveryApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Requests'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share a request'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(
      find.text('Sample evidence only. Nothing is uploaded or verified.'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byType(TextField).at(0),
      'A sample coffee moment',
    );
    await tester.enterText(find.byType(TextField).at(1), 'Fictional cafe');
    await tester.enterText(find.byType(TextField).at(2), '24');
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Submit for review'));
    await tester.tap(find.text('Submit for review'));
    await tester.pumpAndSettle();
    expect(find.text('A sample coffee moment'), findsOneWidget);
    expect(find.text('Private · Awaiting review'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
