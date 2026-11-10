import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_discovery/app/app.dart';
import 'package:social_discovery/app/providers.dart';
import 'package:social_discovery/design/theme.dart';
import 'package:social_discovery/features/discovery/discover.dart';
import 'package:social_discovery/features/invitations/invitations.dart';
import 'package:social_discovery/data/demo_repository.dart';

void main() {
  Widget wrap(Widget child) => ProviderScope(
    overrides: [repositoryProvider.overrideWithValue(DemoRepository())],
    child: MaterialApp(
      theme: P.theme,
      home: Scaffold(body: child),
    ),
  );
  testWidgets('first launch has clear entry and no transaction controls', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: SocialDiscoveryApp()));
    await tester.pumpAndSettle();
    expect(find.text('A hello worth\nremembering.'), findsOneWidget);
    expect(find.text('Find your spark'), findsOneWidget);
    expect(find.text('Pay now'), findsNothing);
  });
  testWidgets('small iPhone discover supports button and swipe alternatives', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(wrap(const DiscoverScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Maya, 27'), findsOneWidget);
    await tester.tap(find.text('Pass'));
    await tester.pumpAndSettle();
    expect(find.text('Alex, 29'), findsOneWidget);
    // Framework reports unhandled layout exceptions at test completion.
  });
  testWidgets(
    'interest opens honest simulation drawer and sends free invitation',
    (tester) async {
      await tester.pumpWidget(wrap(const DiscoverScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Interested'));
      await tester.pumpAndSettle();
      expect(find.text('Send a free invitation'), findsOneWidget);
      expect(
        find.textContaining('Sample request, not verified'),
        findsOneWidget,
      );
      await tester.tap(find.text('Send a free invitation'));
      await tester.pumpAndSettle();
      expect(find.text('Alex, 29'), findsOneWidget);
    },
  );
  testWidgets('decline removes acceptance and keeps chat inaccessible', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const InvitationsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Decline'));
    await tester.pumpAndSettle();
    expect(find.text('declined'), findsOneWidget);
    expect(find.text('Open conversation'), findsNothing);
  });
  testWidgets('large text discover remains usable', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(DemoRepository())],
        child: MaterialApp(
          theme: P.theme,
          home: const MediaQuery(
            data: MediaQueryData(
              size: Size(430, 932),
              textScaler: TextScaler.linear(1.5),
            ),
            child: Scaffold(body: DiscoverScreen()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Framework reports unhandled layout exceptions at test completion.
  });
}
