import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config.dart';
import '../design/theme.dart';
import '../features/auth/entry.dart';
import '../features/discovery/discover.dart';
import '../features/invitations/invitations.dart';
import '../features/requests/requests.dart';
import '../features/chat/chat.dart';
import '../features/account/account.dart';
import '../features/media/recorder.dart';
import '../features/media/gallery.dart';
import '../features/media/telemetry.dart';

class SocialDiscoveryApp extends StatefulWidget {
  const SocialDiscoveryApp({super.key});
  @override
  State<SocialDiscoveryApp> createState() => _SocialDiscoveryAppState();
}

class _SocialDiscoveryAppState extends State<SocialDiscoveryApp> {
  late final GoRouter router;
  final telemetry = PlaybackTelemetry();
  StreamSubscription<AuthState>? auth;
  @override
  void initState() {
    super.initState();
    telemetry.start();
    router = GoRouter(
      initialLocation: AppConfig.webPreview ? '/discover' : '/',
      redirect: (context, state) {
        if (!AppConfig.demo && !AppConfig.configured) {
          return state.uri.path == '/' ? null : '/';
        }
        if (!AppConfig.demo &&
            Supabase.instance.client.auth.currentUser == null &&
            state.uri.path != '/') {
          return '/';
        }
        return null;
      },
      routes: [
        GoRoute(path: '/', builder: (_, __) => const EntryScreen()),
        GoRoute(path: '/gallery', builder: (_, __) => const GalleryScreen()),
        GoRoute(path: '/record', builder: (_, __) => const RecorderScreen()),
        GoRoute(
          path: '/chat/:id',
          builder: (_, s) => ChatScreen(invitationId: s.pathParameters['id']!),
        ),
        ShellRoute(
          builder: (context, state, child) =>
              AppShell(path: state.uri.path, child: child),
          routes: [
            GoRoute(
              path: '/discover',
              builder: (_, __) => const DiscoverScreen(),
            ),
            GoRoute(
              path: '/invitations',
              builder: (_, __) => const InvitationsScreen(),
            ),
            GoRoute(
              path: '/requests',
              builder: (_, __) => const RequestsScreen(),
            ),
            GoRoute(
              path: '/account',
              builder: (_, __) => const AccountScreen(),
            ),
          ],
        ),
      ],
    );
    if (!AppConfig.demo && AppConfig.configured) {
      auth = Supabase.instance.client.auth.onAuthStateChange.listen(
        (_) => router.refresh(),
      );
    }
  }

  @override
  void dispose() {
    telemetry.dispose();
    auth?.cancel();
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Social Discovery',
    debugShowCheckedModeBanner: false,
    theme: P.theme,
    routerConfig: router,
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    supportedLocales: const [Locale('en')],
  );
}

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.path, required this.child});
  final String path;
  final Widget child;
  static const paths = ['/discover', '/invitations', '/requests', '/account'];
  @override
  Widget build(BuildContext context) {
    final index = paths.indexOf(path).clamp(0, 3);
    final wide = MediaQuery.sizeOf(context).width >= 760;
    const destinations = [
      NavigationDestination(
        icon: Icon(Icons.explore_outlined),
        selectedIcon: Icon(Icons.explore),
        label: 'Discover',
      ),
      NavigationDestination(
        icon: Icon(Icons.auto_awesome_outlined),
        selectedIcon: Icon(Icons.auto_awesome),
        label: 'Invitations',
      ),
      NavigationDestination(
        icon: Icon(Icons.receipt_long_outlined),
        label: 'Requests',
      ),
      NavigationDestination(
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person),
        label: 'You',
      ),
    ];
    return Scaffold(
      appBar: AppConfig.webPreview
          ? AppBar(
              toolbarHeight: 44,
              automaticallyImplyLeading: false,
              title: const Text(
                'Studio preview · Sample profiles',
                style: TextStyle(fontSize: 12, color: P.mist),
              ),
              actions: [
                IconButton(
                  tooltip: 'About this preview',
                  icon: const Icon(Icons.info_outline, size: 20),
                  onPressed: () => showDialog(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Explore Social Discovery'),
                      content: const Text(
                        'This is the mobile interface running in your browser. Profiles and requests are fictional. Try discovery, send an invitation, accept the sample incoming invitation and explore chat. No real payments or document uploads occur. Camera recording belongs to the native mobile build. Reloading resets the sample data.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            context.go('/');
                          },
                          child: const Text('View welcome screen'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Explore'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: Row(
          children: [
            if (wide)
              NavigationRail(
                selectedIndex: index,
                onDestinationSelected: (i) => context.go(paths[i]),
                leading: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Monogram(),
                ),
                labelType: NavigationRailLabelType.all,
                destinations: destinations
                    .map(
                      (d) => NavigationRailDestination(
                        icon: d.icon,
                        selectedIcon: d.selectedIcon,
                        label: Text(d.label),
                      ),
                    )
                    .toList(),
              ),
            Expanded(child: child),
          ],
        ),
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (i) => context.go(paths[i]),
              destinations: destinations,
            ),
    );
  }
}
