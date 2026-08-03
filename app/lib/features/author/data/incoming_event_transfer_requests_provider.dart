import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/sync_service.dart' as sync_service;
import 'author_auth_provider.dart';

/// Liefert eingehende, noch offene Event-Uebertragungsanfragen an den
/// eingeloggten Autor (#22/#24). Leere Liste, solange nicht eingeloggt/
/// Passwortwechsel noetig.
final incomingEventTransferRequestsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final auth = ref.watch(authorAuthProvider);
  if (!auth.isLoggedIn || auth.requiresPasswordChange) {
    return <Map<String, dynamic>>[];
  }
  return ref.read(authorAuthProvider.notifier).callAuthenticated(
        (token) => ref
            .read(sync_service.remoteEventSourceProvider)
            .fetchIncomingEventTransferRequests(token: token),
      );
});
