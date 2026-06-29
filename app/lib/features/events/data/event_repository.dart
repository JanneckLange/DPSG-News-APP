import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../../core/services/hive_service.dart';

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return EventRepository(HiveService.getEventsBox());
});

class EventRepository {
  EventRepository(this._box);

  final Box _box;

  List<Map<String, dynamic>> getLocalEvents() {
    return _box.values
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> saveEvents(List<Map<String, dynamic>> events) async {
    await _box.clear();
    for (final event in events) {
      await _box.add(event);
    }
  }
}
