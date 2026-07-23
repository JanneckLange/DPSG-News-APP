import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/sync_service.dart' as sync_service;
import 'author_auth_provider.dart';

/// Liefert die eigenen (veroeffentlichten) Events des eingeloggten Autors.
/// Leere Liste, solange nicht eingeloggt/gesperrt/Passwortwechsel noetig.
final ownEventsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final auth = ref.watch(authorAuthProvider);
  if (!auth.isLoggedIn || auth.isLocked || auth.requiresPasswordChange) {
    return <Map<String, dynamic>>[];
  }
  return ref.read(authorAuthProvider.notifier).callAuthenticated(
        (token) => ref
            .read(sync_service.remoteEventSourceProvider)
            .fetchOwnEvents(token: token),
      );
});

/// Liefert die eigenen Entwuerfe des eingeloggten Autors.
final ownDraftsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final auth = ref.watch(authorAuthProvider);
  if (!auth.isLoggedIn || auth.isLocked || auth.requiresPasswordChange) {
    return <Map<String, dynamic>>[];
  }
  return ref.read(authorAuthProvider.notifier).callAuthenticated(
        (token) => ref
            .read(sync_service.remoteEventSourceProvider)
            .fetchOwnDrafts(token: token),
      );
});
