import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/services/notification_service.dart';
import 'core/services/sync_service.dart';
import 'features/author/presentation/author_screen.dart';
import 'features/calendar/presentation/calendar_screen.dart';
import 'features/events/presentation/events_screen.dart';
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
    Future.microtask(() {
      ref.read(notificationServiceProvider).initialize();
      ref.read(syncServiceProvider).syncEvents();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(currentIndexProvider);
    final pages = <Widget>[
      const EventsScreen(),
      const CalendarScreen(),
      const AuthorScreen(),
      const SettingsScreen(),
    ];

    return MaterialApp(
      title: 'DPSG News APP',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: Scaffold(
        body: pages[currentIndex],
        bottomNavigationBar: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: (index) {
            ref.read(currentIndexProvider.notifier).state = index;
          },
          destinations: const [
            NavigationDestination(icon: Icon(Icons.event), label: 'Events'),
            NavigationDestination(icon: Icon(Icons.calendar_month), label: 'Kalender'),
            NavigationDestination(icon: Icon(Icons.edit), label: 'Autor'),
            NavigationDestination(icon: Icon(Icons.settings), label: 'Einstellungen'),
          ],
        ),
      ),
    );
  }
}
