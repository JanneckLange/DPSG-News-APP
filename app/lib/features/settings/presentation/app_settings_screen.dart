import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/analytics_service.dart';
import '../data/settings_repository.dart';

class AppSettingsScreen extends ConsumerWidget {
  const AppSettingsScreen({super.key});

  static const Map<String, String> _themeOptions = {
    'system': 'Automatisch',
    'light': 'Hell',
    'dark': 'Dunkel',
  };

  static const Map<String, String> _languageOptions = {
    'de': 'Deutsch',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(appThemeModeProvider);
    final analyticsEnabled = ref.watch(analyticsTrackingProvider);
    final appLanguage = ref.watch(appLanguageProvider);
    final autoSaveOnCtaClick = ref.watch(autoSaveEventOnCtaClickProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('App-Einstellungen')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Nutzungs-/Analyse-Tracking'),
                  subtitle: const Text('Hilft uns bei der Verbesserung der App'),
                  value: analyticsEnabled,
                  onChanged: (value) async {
                    await ref.read(analyticsTrackingProvider.notifier).setAnalyticsTracking(value);
                    unawaited(
                      ref.read(analyticsServiceProvider).trackSettingsChange(
                        'analytics_tracking',
                        value,
                        group: 'privacy',
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Event bei Button-Klick automatisch merken'),
                  subtitle: const Text(
                      'Merkt ein Event automatisch, wenn du auf einen Event-Button tippst'),
                  value: autoSaveOnCtaClick,
                  onChanged: (value) async {
                    await ref
                        .read(autoSaveEventOnCtaClickProvider.notifier)
                        .setAutoSaveEventOnCtaClick(value);
                    unawaited(
                      ref.read(analyticsServiceProvider).trackSettingsChange(
                        'auto_save_event_on_cta_click',
                        value,
                        group: 'events',
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                const ListTile(
                  title: Text('Darstellung'),
                  subtitle: Text('Light, Dark oder automatisch'),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: DropdownButtonFormField<String>(
                    initialValue: _themeOptions.containsKey(themeMode) ? themeMode : 'system',
                    decoration: const InputDecoration(labelText: 'Modus'),
                    items: _themeOptions.entries
                        .map(
                          (entry) => DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) async {
                      if (value == null) return;
                      await ref.read(appThemeModeProvider.notifier).setThemeMode(value);
                      unawaited(
                        ref.read(analyticsServiceProvider).trackSettingsChange(
                          'theme_mode',
                          value,
                          group: 'display',
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                const ListTile(
                  title: Text('Sprache'),
                  subtitle: Text('Nur Deutsch verfügbar'),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: DropdownButtonFormField<String>(
                    initialValue: _languageOptions.containsKey(appLanguage) ? appLanguage : 'de',
                    decoration: const InputDecoration(labelText: 'Sprache'),
                    items: _languageOptions.entries
                        .map(
                          (entry) => DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) async {
                      if (value == null) return;
                      await ref.read(appLanguageProvider.notifier).setAppLanguage(value);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
