import 'dart:developer';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wiredash/wiredash.dart';

import 'core/config/app_config.dart';
import 'core/services/app_navigation_service.dart';
import 'core/services/logging_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/sync_service.dart';
import 'core/services/usage_tracking_service.dart';
import 'features/author/presentation/author_screen.dart';
import 'features/calendar/presentation/calendar_screen.dart';
import 'features/events/presentation/events_screen.dart';
import 'features/settings/data/settings_repository.dart';
import 'features/settings/presentation/settings_screen.dart';

final currentIndexProvider = StateProvider<int>((ref) => 0);

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> with WidgetsBindingObserver {
  late final LoggingService _logger;
  late final UsageTrackingService _usageTracking;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _logger = ref.read(loggingServiceProvider);
    _usageTracking = UsageTrackingService(logger: _logger);

    unawaited(_logger.logInfo('lifecycle', 'app_started'));
    unawaited(_usageTracking.flushPendingSession());
    _usageTracking.startSession();

    Future.microtask(() async {
      log('App initState: starting notification initialization');
      await ref.read(notificationServiceProvider)
          .initialize()
          .then((_) => log('NotificationService initialize completed'))
          .catchError((error, stack) {
        log('NotificationService initialize failed: $error');
        log('$stack');
      });
      log('App initState: starting syncEvents');
      ref.read(syncServiceProvider).syncEvents();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_logger.logInfo('lifecycle', 'app_resumed'));
      unawaited(_usageTracking.resume());
      _isPaused = false;
    } else if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      if (!_isPaused) {
        _isPaused = true;
        unawaited(_usageTracking.pause());
      }
      unawaited(_logger.logInfo('lifecycle', 'app_${state.name}'));
    }
    super.didChangeAppLifecycleState(state);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_usageTracking.endSession());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(currentIndexProvider);
    final authorMode = ref.watch(authorModeProvider);
    final appThemeMode = ref.watch(appThemeModeProvider);
    final navigatorKey = ref.watch(appNavigatorKeyProvider);

    final pages = <Widget>[
      const EventsScreen(),
      const CalendarScreen(),
      if (authorMode) const AuthorScreen(),
      const SettingsScreen(),
    ];

    final destinations = <NavigationDestination>[
      const NavigationDestination(icon: Icon(Icons.event), label: 'Events'),
      const NavigationDestination(icon: Icon(Icons.calendar_month), label: 'Kalender'),
      if (authorMode) const NavigationDestination(icon: Icon(Icons.edit), label: 'Autor'),
      const NavigationDestination(icon: Icon(Icons.settings), label: 'Einstellungen'),
    ];

    final safeIndex = currentIndex.clamp(0, pages.length - 1);
    if (currentIndex != safeIndex) {
      Future.microtask(() => ref.read(currentIndexProvider.notifier).state = safeIndex);
    }

    final effectiveThemeMode = switch (appThemeMode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    final materialApp = MaterialApp(
      title: 'DPSG News APP',
      theme: ThemeData(primarySwatch: Colors.blue),
      darkTheme: ThemeData(brightness: Brightness.dark, colorSchemeSeed: Colors.blue),
      themeMode: effectiveThemeMode,
      navigatorKey: navigatorKey,
      navigatorObservers: [
        AppNavigationLoggingObserver(logger: _logger),
      ],
      builder: (context, child) {
        if (child == null) {
          return const SizedBox.shrink();
        }
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) {
            unawaited(_logger.logTap(x: event.position.dx, y: event.position.dy));
          },
          child: child,
        );
      },
      home: Scaffold(
        body: pages[safeIndex],
        bottomNavigationBar: NavigationBar(
          selectedIndex: safeIndex,
          onDestinationSelected: (index) {
            ref.read(currentIndexProvider.notifier).state = index;
          },
          destinations: destinations,
        ),
      ),
    );

    if (!AppConfig.hasWiredashConfig) {
      return materialApp;
    }

    return Wiredash(
      projectId: AppConfig.wiredashProjectId,
      secret: AppConfig.wiredashSecret,
      child: materialApp,
    );
  }
}
