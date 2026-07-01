import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/notification_service.dart';
import '../data/settings_repository.dart';
import 'dv_selection_screen.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsEnabled = ref.watch(notificationsEnabledProvider);
    final newEventPushEnabled = ref.watch(newEventPushEnabledProvider);
    final subscribedEventsReminder =
        ref.watch(subscribedEventsReminderProvider);
    final deadlineReminder = ref.watch(deadlineReminderProvider);
    final weeklyPushSummary = ref.watch(weeklyPushSummaryProvider);
    final subscribedEventsReminderDaysBefore =
        ref.watch(subscribedEventsReminderDaysBeforeProvider);
    final deadlineReminderDaysBefore =
        ref.watch(deadlineReminderDaysBeforeProvider);

    final allowIndividualSettings = notificationsEnabled;

    return Scaffold(
      appBar: AppBar(title: const Text('Benachrichtigungen')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: EdgeInsets.zero,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Benachrichtigungen aktiv'),
                  subtitle: Text(
                    notificationsEnabled
                        ? 'Schalte alle Benachrichtigungen dieser App aus'
                        : 'Schalte alle Benachrichtigungen dieser App ein',
                  ),
                  value: notificationsEnabled,
                  onChanged: (value) async {
                    final repository = ref.read(settingsRepositoryProvider);
                    await repository.resetNotificationSettingsToDefaults(
                        notificationsEnabled: value);

                    ref.invalidate(notificationsEnabledProvider);
                    ref.invalidate(newEventPushEnabledProvider);
                    ref.invalidate(subscribedEventsReminderProvider);
                    ref.invalidate(deadlineReminderProvider);
                    ref.invalidate(weeklyPushSummaryProvider);
                    ref.invalidate(subscribedEventsReminderDaysBeforeProvider);
                    ref.invalidate(deadlineReminderDaysBeforeProvider);

                    await ref
                        .read(notificationServiceProvider)
                        .refreshTopicSubscriptions();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Neue Veranstaltungen'),
                  subtitle: const Text(
                      'Benachrichtigungen zu neu veröffentlichten Veranstaltungen'),
                  value: newEventPushEnabled,
                  onChanged: allowIndividualSettings
                      ? (value) async {
                          await ref
                              .read(newEventPushEnabledProvider.notifier)
                              .setNewEventPushEnabled(value);
                          await ref
                              .read(notificationServiceProvider)
                              .refreshTopicSubscriptions();
                        }
                      : null,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                              'Interessen anpassen: Diözesen und Themen auswählen'),
                        ),
                        TextButton(
                          onPressed: allowIndividualSettings
                              ? () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            const DvSelectionScreen()),
                                  );
                                }
                              : null,
                          child: const Text('Auswählen'),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Erinnerung für zugesagte Veranstaltungen'),
                  subtitle: const Text(
                      'Hinweis auf Veranstaltungen, denen du zugesagt hast'),
                  value: subscribedEventsReminder,
                  onChanged: allowIndividualSettings
                      ? (value) async {
                          await ref
                              .read(subscribedEventsReminderProvider.notifier)
                              .setSubscribedEventsReminderEnabled(value);
                        }
                      : null,
                ),
                ListTile(
                  title: const Text('Tage vorher'),
                  trailing: DropdownButton<int>(
                    value: subscribedEventsReminderDaysBefore,
                    onChanged: allowIndividualSettings &&
                            subscribedEventsReminder
                        ? (value) async {
                            if (value == null) return;
                            await ref
                                .read(subscribedEventsReminderDaysBeforeProvider
                                    .notifier)
                                .setSubscribedEventsReminderDaysBefore(value);
                          }
                        : null,
                    items: List.generate(
                      10,
                      (index) => DropdownMenuItem<int>(
                        value: index + 1,
                        child: Text('${index + 1}'),
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Erinnerung vor Anmeldeschluss'),
                  subtitle: const Text('Hinweis vor dem Ende der Anmeldefrist'),
                  value: deadlineReminder,
                  onChanged: allowIndividualSettings
                      ? (value) async {
                          await ref
                              .read(deadlineReminderProvider.notifier)
                              .setDeadlineReminderEnabled(value);
                        }
                      : null,
                ),
                ListTile(
                  title: const Text('Tage vorher'),
                  trailing: DropdownButton<int>(
                    value: deadlineReminderDaysBefore,
                    onChanged: allowIndividualSettings && deadlineReminder
                        ? (value) async {
                            if (value == null) return;
                            await ref
                                .read(
                                    deadlineReminderDaysBeforeProvider.notifier)
                                .setDeadlineReminderDaysBefore(value);
                          }
                        : null,
                    items: List.generate(
                      10,
                      (index) => DropdownMenuItem<int>(
                        value: index + 1,
                        child: Text('${index + 1}'),
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Wochenübersicht'),
                  subtitle: const Text(
                      'Wöchentliche Zusammenfassung deiner relevanten Termine'),
                  value: weeklyPushSummary,
                  onChanged: allowIndividualSettings
                      ? (value) async {
                          await ref
                              .read(weeklyPushSummaryProvider.notifier)
                              .setWeeklyPushSummaryEnabled(value);
                        }
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
