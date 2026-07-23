import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_toastify/my_toastify.dart';

import '../../features/events/data/remote_event_source.dart';
import 'app_navigation_service.dart';

/// Zeigt eine Fehlermeldung als Toast ueber den global registrierten
/// Navigator-Context an, unabhaengig davon, ob der Aufrufer selbst einen
/// lokalen Scaffold-Kontext besitzt.
void showErrorToast(WidgetRef ref, String message) {
  showErrorToastForKey(ref.read(appNavigatorKeyProvider), message);
}

/// Wie [showErrorToast], aber fuer Aufrufer ohne [WidgetRef] (z.B. innerhalb
/// eines Notifiers, der nur ein einfaches [Ref] besitzt).
void showErrorToastForKey(
    GlobalKey<NavigatorState> navigatorKey, String message) {
  final context = navigatorKey.currentContext;
  if (context == null || !context.mounted) return;

  final safeMessage = message.trim().length < 5
      ? 'Ein Fehler ist aufgetreten.'
      : message.trim();

  Toastify.show(
    context,
    message: safeMessage,
    type: ToastType.error,
    position: ToastPosition.bottom,
    style: ToastStyle.snackBar,
  );
}

/// Extrahiert eine nutzerverstaendliche Fehlermeldung aus einem beliebigen
/// Fehler, bevorzugt die vom Server gelieferte Klartext-Meldung.
String describeRemoteError(Object error) {
  if (error is RemoteEventSourceException) {
    return error.serverMessage ?? error.message;
  }
  return error.toString();
}
