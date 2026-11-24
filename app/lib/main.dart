import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:material_ui/material_ui.dart';

import 'firebase_options.dart';
import 'src/account.dart';
import 'src/account_page.dart';
import 'src/app_state.dart';
import 'src/launch_list_page.dart';
import 'src/launch_page.dart';
import 'src/launch_repository.dart';
import 'src/events_page.dart';
import 'src/explore_page.dart';
import 'src/news_page.dart';
import 'src/people_page.dart';
import 'src/space_data.dart';
import 'src/station_page.dart';
import 'src/theme.dart';
import 'src/widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (kIsWeb) {
    // Phones keep a local copy by default. On the web, opt in, so an installed
    // LaunchWatch opens offline with the launches it last saw. Several tabs
    // share one copy.
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      webPersistentTabManager: WebPersistentMultipleTabManager(),
    );
  }
  // Flutter web paints to a canvas. Building the semantics tree up front lets
  // screen readers and browser tools read the page without a hidden toggle.
  if (kIsWeb) SemanticsBinding.instance.ensureSemantics();

  final account = AccountController();
  unawaited(account.start());
  runApp(LaunchWatchApp(repository: LaunchRepository(FirebaseFirestore.instance), space: SpaceRepository(FirebaseFirestore.instance), account: account));
}

class LaunchWatchApp extends StatefulWidget {
  const LaunchWatchApp({super.key, required this.repository, required this.space, required this.account});

  final LaunchRepository repository;
  final SpaceRepository space;
  final AccountController account;

  @override
  State<LaunchWatchApp> createState() => _LaunchWatchAppState();
}

class _LaunchWatchAppState extends State<LaunchWatchApp> {
  final _navigator = GlobalKey<NavigatorState>();
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  final _subs = <StreamSubscription<dynamic>>[];

  @override
  void initState() {
    super.initState();
    final notifications = widget.account.notifications;
    _subs
      ..add(notifications.opened.listen((id) => _navigator.currentState?.pushNamed('/launch/$id')))
      ..add(notifications.foreground.listen((alert) {
        _messenger.currentState?.showSnackBar(SnackBar(
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(alert.title, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (alert.body.isNotEmpty) Text(alert.body),
          ]),
          action: alert.launchId == null ? null : SnackBarAction(label: 'View', onPressed: () => _navigator.currentState?.pushNamed('/launch/${alert.launchId}')),
        ));
      }));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    widget.account.dispose();
    super.dispose();
  }

  Route<dynamic>? _route(RouteSettings settings) {
    final uri = Uri.parse(settings.name ?? '/');
    final segments = uri.pathSegments;
    if (segments.length == 2) {
      final id = segments[1];
      final Widget? page = switch (segments[0]) {
        'launch' => LaunchPage(id: id, repository: widget.repository),
        'event' => EventPage(id: id),
        'station' => StationPage(id: id),
        'astronaut' => AstronautPage(id: id),
        _ => null,
      };
      if (page != null) return MaterialPageRoute<void>(settings: settings, builder: (_) => page);
    }
    final tab = switch (segments.isEmpty ? '' : segments.first) {
      'events' => 1,
      'news' => 2,
      'explore' || 'vehicles' || 'organisations' => 3,
      'account' => 4,
      _ => 0,
    };
    HomeShell.currentTab.value = tab;
    return MaterialPageRoute<void>(settings: RouteSettings(name: HomeShell.paths[tab], arguments: settings.arguments), builder: (_) => HomeShell(repository: widget.repository, initialTab: tab));
  }

  @override
  Widget build(BuildContext context) {
    return LaunchWatchScope(
      state: widget.account,
      repository: widget.repository,
      space: widget.space,
      child: MaterialApp(
        title: 'LaunchWatch',
        debugShowCheckedModeBanner: false,
        theme: launchWatchTheme(),
        navigatorKey: _navigator,
        scaffoldMessengerKey: _messenger,
        onGenerateRoute: _route,
        navigatorObservers: [_TabUrlKeeper()],
        onGenerateInitialRoutes: (name) {
          final uri = Uri.parse(name);
          final home = _route(const RouteSettings(name: '/'))!;
          if (uri.pathSegments.length == 2 && const {'launch', 'event', 'station', 'astronaut'}.contains(uri.pathSegments[0])) return [home, _route(RouteSettings(name: name))!];
          return [_route(RouteSettings(name: name))!];
        },
        builder: (context, child) => ColoredBox(color: launchCanvas, child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}

/// Coming back from a launch or event page, the browser would otherwise show
/// the path of whichever tab the app opened on. Put the current tab's path back.
class _TabUrlKeeper extends NavigatorObserver {
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute?.isFirst != true) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemNavigator.routeInformationUpdated(uri: Uri(path: HomeShell.paths[HomeShell.currentTab.value]), replace: true);
    });
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.repository, this.initialTab = 0});

  final LaunchRepository repository;
  final int initialTab;

  static const paths = ['/', '/events', '/news', '/explore', '/account'];
  static final currentTab = ValueNotifier<int>(0);

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _index = widget.initialTab;
  final _selection = ValueNotifier<String?>(null);
  late final List<Widget> _pages = [
    LaunchesPage(repository: widget.repository),
    const EventsPage(),
    const NewsPage(),
    ExplorePage(repository: widget.repository),
    const AccountPage(),
  ];

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  void _select(int index) {
    setState(() => _index = index);
    HomeShell.currentTab.value = index;
    SystemNavigator.routeInformationUpdated(uri: Uri(path: HomeShell.paths[index]), replace: true);
  }

  @override
  Widget build(BuildContext context) {
    final account = LaunchWatchScope.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= launchWideBreakpoint;
    final split = width >= launchSplitBreakpoint;
    final accountIcon = Badge(
      isLabelVisible: account.unread > 0,
      label: Text('${account.unread}'),
      backgroundColor: launchLive,
      child: const Icon(Icons.person_outline),
    );

    Widget body = IndexedStack(index: _index, children: _pages);

    if (!wide) {
      return Scaffold(
        body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640), child: body)),
        bottomNavigationBar: DecoratedBox(
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: launchLine))),
          child: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: _select,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              const NavigationDestination(icon: Icon(Icons.rocket_launch_outlined), selectedIcon: Icon(Icons.rocket_launch), label: 'Launches', tooltip: ''),
              const NavigationDestination(icon: Icon(Icons.event_outlined), selectedIcon: Icon(Icons.event), label: 'Events', tooltip: ''),
              const NavigationDestination(icon: Icon(Icons.newspaper_outlined), selectedIcon: Icon(Icons.newspaper), label: 'News', tooltip: ''),
              const NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: 'Explore', tooltip: ''),
              NavigationDestination(icon: accountIcon, selectedIcon: const Icon(Icons.person), label: 'Account', tooltip: ''),
            ],
          ),
        ),
      );
    }

    if (split && _index == 0) {
      body = SplitSelection(
        selection: _selection,
        child: Row(children: [
          SizedBox(width: 460, child: _pages[0]),
          const VerticalDivider(width: 1),
          Expanded(
            child: ValueListenableBuilder<String?>(
              valueListenable: _selection,
              builder: (context, id, _) => id == null
                  ? const EmptyState(icon: Icons.touch_app_outlined, title: 'Select a launch', body: 'Its mission brief, schedule history, and alerts open here.')
                  : Scaffold(body: SafeArea(child: LaunchDetailView(key: ValueKey(id), id: id, repository: widget.repository, embedded: true))),
            ),
          ),
        ]),
      );
    }

    return Scaffold(
      body: Row(children: [
        NavigationRail(
          extended: width >= 1280,
          selectedIndex: _index,
          onDestinationSelected: _select,
          labelType: width >= 1280 ? NavigationRailLabelType.none : NavigationRailLabelType.all,
          leading: Padding(
            padding: const EdgeInsets.fromLTRB(8, 20, 8, 20),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: launchSurfaceRaised, borderRadius: BorderRadius.circular(9), border: Border.all(color: launchLineStrong)),
                child: const Icon(Icons.rocket_launch, size: 18, color: launchAccent),
              ),
              if (width >= 1280) ...[
                const SizedBox(width: 10),
                const Text('LaunchWatch', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, letterSpacing: -0.3)),
              ],
            ]),
          ),
          destinations: [
            const NavigationRailDestination(icon: Icon(Icons.rocket_launch_outlined), selectedIcon: Icon(Icons.rocket_launch), label: Text('Launches')),
            const NavigationRailDestination(icon: Icon(Icons.event_outlined), selectedIcon: Icon(Icons.event), label: Text('Events')),
            const NavigationRailDestination(icon: Icon(Icons.newspaper_outlined), selectedIcon: Icon(Icons.newspaper), label: Text('News')),
            const NavigationRailDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: Text('Explore')),
            NavigationRailDestination(icon: accountIcon, selectedIcon: const Icon(Icons.person), label: const Text('Account')),
          ],
        ),
        const VerticalDivider(width: 1),
        Expanded(child: split && _index == 0 ? body : Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 900), child: body))),
      ]),
    );
  }
}
