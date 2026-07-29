import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_navigation_service.dart';
import '../../../core/services/error_toast_service.dart';
import '../../../core/services/secure_storage_service.dart';
import '../../../core/services/sync_service.dart' as sync_service;
import '../../events/data/remote_event_source.dart';
import '../../settings/data/settings_repository.dart';

class AuthorAuthState {
  const AuthorAuthState({
    required this.isLoggedIn,
    this.token,
    this.refreshToken,
    this.authorId,
    this.username,
    this.isAdmin = false,
    this.requiresPasswordChange = false,
    this.expiresAt,
    this.refreshExpiresAt,
    this.layerGrantIds = const <int>[],
    this.topicGrantIds = const <int>[],
  });

  final bool isLoggedIn;
  final String? token;
  final String? refreshToken;
  final int? authorId;
  final String? username;
  final bool isAdmin;
  final bool requiresPasswordChange;
  final DateTime? expiresAt;
  final DateTime? refreshExpiresAt;
  final List<int> layerGrantIds;
  final List<int> topicGrantIds;

  AuthorAuthState copyWith({
    bool? isLoggedIn,
    String? token,
    String? refreshToken,
    int? authorId,
    String? username,
    bool? isAdmin,
    bool? requiresPasswordChange,
    DateTime? expiresAt,
    DateTime? refreshExpiresAt,
    List<int>? layerGrantIds,
    List<int>? topicGrantIds,
  }) {
    return AuthorAuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      token: token ?? this.token,
      refreshToken: refreshToken ?? this.refreshToken,
      authorId: authorId ?? this.authorId,
      username: username ?? this.username,
      isAdmin: isAdmin ?? this.isAdmin,
      requiresPasswordChange:
          requiresPasswordChange ?? this.requiresPasswordChange,
      expiresAt: expiresAt ?? this.expiresAt,
      refreshExpiresAt: refreshExpiresAt ?? this.refreshExpiresAt,
      layerGrantIds: layerGrantIds ?? this.layerGrantIds,
      topicGrantIds: topicGrantIds ?? this.topicGrantIds,
    );
  }

  static AuthorAuthState signedOut() =>
      const AuthorAuthState(isLoggedIn: false, isAdmin: false);
}

final authorAuthProvider =
    StateNotifierProvider<AuthorAuthNotifier, AuthorAuthState>((ref) {
  final repository = ref.read(settingsRepositoryProvider);
  final remote = ref.read(sync_service.remoteEventSourceProvider);
  final storage = ref.read(secureStorageServiceProvider);
  return AuthorAuthNotifier(
      repository: repository, remote: remote, secureStorage: storage, ref: ref);
});

class AuthorAuthNotifier extends StateNotifier<AuthorAuthState> {
  AuthorAuthNotifier({
    required SettingsRepository repository,
    required RemoteEventSource remote,
    required SecureStorageService secureStorage,
    required Ref ref,
    bool restoreSessionOnInit = true,
  })  : _repository = repository,
        _remote = remote,
        _secureStorage = secureStorage,
        _ref = ref,
        super(AuthorAuthState.signedOut()) {
    if (restoreSessionOnInit) {
      unawaited(_restoreSession());
    }
  }

  final SettingsRepository _repository;
  final RemoteEventSource _remote;
  final SecureStorageService _secureStorage;
  final Ref _ref;

  Future<void> _restoreSession() async {
    final storedTokens = await _secureStorage.readAuthorTokens();
    if (storedTokens == null) {
      final legacyToken = _repository.getLegacyAuthorAuthToken();
      if (legacyToken != null && legacyToken.isNotEmpty) {
        await _repository.clearLegacyAuthorAuthToken();
      }
      return;
    }
    state = AuthorAuthState(
      isLoggedIn: true,
      token: storedTokens.accessToken,
      refreshToken: storedTokens.refreshToken,
      authorId: _repository.getAuthorId(),
      username: _repository.getAuthorUsername(),
      isAdmin: _repository.getAuthorIsAdmin(),
      requiresPasswordChange: _repository.getAuthorRequiresPasswordChange(),
      expiresAt: DateTime.tryParse(storedTokens.accessExpiresAt),
      refreshExpiresAt: DateTime.tryParse(storedTokens.refreshExpiresAt),
      layerGrantIds: _repository.getAuthorLayerGrantIds(),
      topicGrantIds: _repository.getAuthorTopicGrantIds(),
    );
  }

  Future<void> _persistSession(AuthorLoginSession session) async {
    await _secureStorage.saveAuthorTokens(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      accessExpiresAt: session.accessExpiresAt,
      refreshExpiresAt: session.refreshExpiresAt,
    );
    await _repository.saveAuthorSession(
      authorId: session.authorId,
      username: session.username,
      isAdmin: session.isAdmin,
      requiresPasswordChange: session.requiresPasswordChange,
      layerGrantIds: session.layerGrantIds,
      topicGrantIds: session.topicGrantIds,
    );
    await _repository.clearLegacyAuthorAuthToken();
    state = AuthorAuthState(
      isLoggedIn: true,
      token: session.accessToken,
      refreshToken: session.refreshToken,
      authorId: session.authorId,
      username: session.username,
      isAdmin: session.isAdmin,
      requiresPasswordChange: session.requiresPasswordChange,
      expiresAt: DateTime.tryParse(session.accessExpiresAt),
      refreshExpiresAt: DateTime.tryParse(session.refreshExpiresAt),
      layerGrantIds: session.layerGrantIds,
      topicGrantIds: session.topicGrantIds,
    );
  }

  Future<void> login(String username, String password) async {
    final session =
        await _remote.loginAuthor(username: username, password: password);
    await _persistSession(session);
  }

  Future<void> logout() async {
    final token = state.token;
    try {
      if (token != null && token.isNotEmpty) {
        await _remote.logoutAuthor(token: token);
      }
    } finally {
      await _secureStorage.clearAuthorTokens();
      await _repository.clearAuthorSession();
      state = AuthorAuthState.signedOut();
    }
  }

  Future<void> refreshSession() async {
    final token = await getValidAccessToken();
    if (token == null || token.isEmpty) {
      return;
    }
    final session = await _remote.fetchAuthorSession(token: token);
    await _repository
        .setAuthorRequiresPasswordChange(session.requiresPasswordChange);
    await _repository.setAuthorIsAdmin(session.isAdmin);
    await _repository.setAuthorGrants(
      layerGrantIds: session.layerGrantIds,
      topicGrantIds: session.topicGrantIds,
    );
    state = state.copyWith(
      requiresPasswordChange: session.requiresPasswordChange,
      isAdmin: session.isAdmin,
      layerGrantIds: session.layerGrantIds,
      topicGrantIds: session.topicGrantIds,
    );
  }

  Future<void> changePassword(
      {String? oldPassword, required String newPassword}) async {
    final token = await getValidAccessToken();
    if (token == null || token.isEmpty) {
      throw StateError('Not logged in');
    }
    await _remote.changeAuthorPassword(
      token: token,
      oldPassword: oldPassword,
      newPassword: newPassword,
    );
    await _repository.setAuthorRequiresPasswordChange(false);
    state = state.copyWith(requiresPasswordChange: false);
  }

  Future<String?> getValidAccessToken() async {
    if (!state.isLoggedIn) {
      return null;
    }
    final token = state.token;
    final expiresAt = state.expiresAt;
    if (token != null &&
        token.isNotEmpty &&
        expiresAt != null &&
        DateTime.now().toUtc().isBefore(
            expiresAt.toUtc().subtract(const Duration(seconds: 30)))) {
      return token;
    }
    return _forceRefresh();
  }

  /// Erneuert den Access-Token unabhaengig von der lokal gespeicherten
  /// Ablaufzeit -- wird sowohl vom proaktiven [getValidAccessToken] als auch
  /// reaktiv von [callAuthenticated] nach einem Live-401 genutzt.
  Future<String?> _forceRefresh() async {
    final refreshToken = state.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      await logout();
      return null;
    }
    try {
      final refreshed =
          await _remote.refreshAuthorSession(refreshToken: refreshToken);
      await _persistSession(refreshed);
      return state.token;
    } on RemoteEventSourceException catch (error) {
      if (error.statusCode == 401) {
        await logout();
        return null;
      }
      rethrow;
    }
  }

  /// Fuehrt einen authentifizierten Request aus. Antwortet der Server dabei
  /// mit 401 (z.B. weil die Session zwischenzeitlich anderswo widerrufen
  /// wurde), wird der Token einmal zwangserneuert und der Request einmal
  /// automatisch wiederholt. Schlaegt auch das fehl, wird der Nutzer
  /// ausgeloggt und zur Root-Route zurueckgeschickt.
  Future<T> callAuthenticated<T>(
      Future<T> Function(String token) request) async {
    final token = await getValidAccessToken();
    if (token == null) {
      throw StateError('Not logged in');
    }
    try {
      return await request(token);
    } on RemoteEventSourceException catch (error) {
      if (error.statusCode != 401) {
        rethrow;
      }
      final refreshedToken = await _forceRefresh();
      if (refreshedToken == null) {
        _notifySessionExpired();
        rethrow;
      }
      try {
        return await request(refreshedToken);
      } on RemoteEventSourceException catch (retryError) {
        if (retryError.statusCode == 401) {
          await logout();
          _notifySessionExpired();
        }
        rethrow;
      }
    }
  }

  void _notifySessionExpired() {
    final navigatorKey = _ref.read(appNavigatorKeyProvider);
    navigatorKey.currentState?.popUntil((route) => route.isFirst);
    showErrorToastForKey(
        navigatorKey, 'Sitzung abgelaufen, bitte erneut anmelden.');
  }

  Future<void> onAppBackgrounded() async {
    if (!state.isLoggedIn) {
      return;
    }
    await _repository.setAuthorLastBackgroundedAt(DateTime.now().toUtc());
  }

  Future<void> onAppResumed() async {
    if (!state.isLoggedIn) {
      return;
    }
    await _repository.setAuthorLastBackgroundedAt(null);
  }
}
