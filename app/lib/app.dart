import 'dart:developer';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wiredash/wiredash.dart';

import 'core/config/app_config.dart';
import 'core/services/analytics_service.dart';
import 'core/services/app_navigation_service.dart';
import 'core/services/logging_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/sync_service.dart';
import 'core/services/usage_tracking_service.dart';
import 'core/services/wiredash_metadata_service.dart';
import 'features/author/presentation/author_screen.dart';
import 'features/author/data/author_auth_provider.dart';
import 'features/calendar/presentation/calendar_screen.dart';
import 'features/events/presentation/events_screen.dart';
import 'features/settings/data/settings_repository.dart' as settings_repository;
import 'features/settings/presentation/settings_screen.dart';

final appThemeModeProvider = settings_repository.appThemeModeProvider;

final currentIndexProvider = StateProvider<int>((ref) => 0);

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> with WidgetsBindingObserver {
  late final LoggingService _logger;
  late final AnalyticsService _analytics;
  late final UsageTrackingService _usageTracking;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _logger = ref.read(loggingServiceProvider);
    _analytics = ref.read(analyticsServiceProvider);
    _usageTracking = UsageTrackingService(logger: _logger);

    unawaited(_logger.logInfo('lifecycle', 'app_started'));
    unawaited(_analytics.initialize());
    unawaited(_analytics.trackScreenView('app_start'));
    unawaited(_analytics.trackFeatureEvent('app_started', screen: 'app', source: 'launch'));
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
    final authorAuth = ref.read(authorAuthProvider.notifier);
    if (state == AppLifecycleState.resumed) {
      unawaited(_logger.logInfo('lifecycle', 'app_resumed'));
      unawaited(_analytics.capture('app_resumed'));
      unawaited(_usageTracking.resume());
      unawaited(authorAuth.onAppResumed());
      _isPaused = false;
    } else if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      if (!_isPaused) {
        _isPaused = true;
        unawaited(_usageTracking.pause());
        unawaited(_analytics.capture('app_backgrounded'));
        unawaited(authorAuth.onAppBackgrounded());
      }
      unawaited(_logger.logInfo('lifecycle', 'app_${state.name}'));
    }
    super.didChangeAppLifecycleState(state);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_usageTracking.endSession());
    unawaited(_analytics.capture('app_closed'));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(currentIndexProvider);
    final authorAuth = ref.watch(authorAuthProvider);
    final appThemeMode = ref.watch(appThemeModeProvider);
    final navigatorKey = ref.watch(appNavigatorKeyProvider);

    final pages = <Widget>[
      const EventsScreen(),
      const CalendarScreen(),
      if (authorAuth.isLoggedIn) const AuthorScreen(),
      const SettingsScreen(),
    ];

    final destinations = <NavigationDestination>[
      const NavigationDestination(icon: Icon(Icons.event), label: 'Events'),
      const NavigationDestination(icon: Icon(Icons.calendar_month), label: 'Kalender'),
      if (authorAuth.isLoggedIn) const NavigationDestination(icon: Icon(Icons.edit), label: 'Autor'),
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

    final locale = Localizations.maybeLocaleOf(context);
    final safeLocale = locale != null && locale.languageCode.isNotEmpty
        ? locale
        : const Locale('de', 'DE');
    final eventsAsync = ref.watch(eventsProvider);
    final settingsRepo = ref.watch(settings_repository.settingsRepositoryProvider);
    final selectedDvs = settingsRepo.getSelectedDvs();
    final displayedEvents = eventsAsync.valueOrNull ?? <Map<String, dynamic>>[];
    final filteredEvents = selectedDvs.isEmpty
        ? displayedEvents
        : displayedEvents.where((event) => selectedDvs.contains(event['dv'] as String?)).toList();
    final wiredashMetadata = WiredashMetadataService.buildSafeCustomMetadata(
      locale: safeLocale,
      platform: defaultTargetPlatform,
      isReleaseMode: !const bool.fromEnvironment('dart.vm.product', defaultValue: false),
      appThemeMode: appThemeMode,
      isLoggedIn: authorAuth.isLoggedIn,
      displayedEventCount: filteredEvents.length,
      selectedDvs: selectedDvs,
    );

    final materialApp = MaterialApp(
      title: 'DPSG News APP',
      theme: ThemeData(primarySwatch: Colors.blue),
      darkTheme: ThemeData(brightness: Brightness.dark, colorSchemeSeed: Colors.blue),
      themeMode: effectiveThemeMode,
      navigatorKey: navigatorKey,
      navigatorObservers: [
        AppNavigationLoggingObserver(logger: _logger, analytics: _analytics),
      ],
      builder: (context, child) {
        if (child == null) {
          return const SizedBox.shrink();
        }
        return child;
      },
      home: Scaffold(
        body: pages[safeIndex],
        bottomNavigationBar: NavigationBar(
          selectedIndex: safeIndex,
          onDestinationSelected: (index) {
            ref.read(currentIndexProvider.notifier).state = index;
            unawaited(
              _analytics.trackUiClick(
                'bottom_navigation',
                screen: 'app',
                action: 'select',
                target: destinations[index].label,
              ),
            );
          },
          destinations: destinations,
        ),
      ),
    );

    if (!AppConfig.hasWiredashConfig) {
      debugPrint('Wiredash config missing: projectId=${AppConfig.wiredashProjectId.isNotEmpty}, secret=${AppConfig.wiredashSecret.isNotEmpty}');
      return materialApp;
    }

    return Wiredash(
      projectId: AppConfig.wiredashProjectId,
      secret: AppConfig.wiredashSecret,
      environment: kDebugMode ? 'debug' : 'release',
      options: WiredashOptionsData(locale: safeLocale),
      collectMetaData: (metaData) async {
        metaData.custom.addAll(wiredashMetadata);
        return metaData;
      },
      child: materialApp,
    );
  }
}
