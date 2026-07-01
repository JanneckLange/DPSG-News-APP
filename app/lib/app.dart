import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/services/notification_service.dart';
import 'core/services/sync_service.dart';
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

class _AppState extends ConsumerState<App> {
  @override
  void initState() {
    super.initState();
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
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(currentIndexProvider);
    final authorMode = ref.watch(authorModeProvider);

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

    return MaterialApp(
      title: 'DPSG News APP',
      theme: ThemeData(primarySwatch: Colors.blue),
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
  }
}
