import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/sync_service.dart' as sync_service;
import '../../author/data/author_auth_provider.dart';

/// Liefert die zuletzt erstellte Uebertragungsanfrage fuer ein eigenes Event
/// (#24: Status "ausstehend/angenommen/abgelehnt" sichtbar machen), oder
/// null falls es nie eine gab. Nur fuer den Event-Eigentuemer aufrufbar
/// (server-seitig per requireOwnEvent durchgesetzt).
final outgoingEventTransferRequestProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, int>((ref, eventId) async {
  final auth = ref.watch(authorAuthProvider);
  if (!auth.isLoggedIn || auth.requiresPasswordChange) {
    return null;
  }
  final requests = await ref.read(authorAuthProvider.notifier).callAuthenticated(
        (token) => ref
            .read(sync_service.remoteEventSourceProvider)
            .fetchOutgoingEventTransferRequests(token: token, eventId: eventId),
      );
  return requests.isEmpty ? null : requests.first;
});
