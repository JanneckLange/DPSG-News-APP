import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../../core/services/secure_storage_service.dart';
import '../../../core/services/sync_service.dart' as sync_service;
import '../../events/data/remote_event_source.dart';
import '../../settings/data/settings_repository.dart';

const Duration authorLockTimeout = Duration(seconds: 60);

class AuthorAuthState {
  const AuthorAuthState({
    required this.isLoggedIn,
    required this.isLocked,
    this.token,
    this.refreshToken,
    this.authorId,
    this.username,
    this.isAdmin = false,
    this.requiresPasswordChange = false,
    this.expiresAt,
    this.refreshExpiresAt,
  });

  final bool isLoggedIn;
  final bool isLocked;
  final String? token;
  final String? refreshToken;
  final int? authorId;
  final String? username;
  final bool isAdmin;
  final bool requiresPasswordChange;
  final DateTime? expiresAt;
  final DateTime? refreshExpiresAt;

  AuthorAuthState copyWith({
    bool? isLoggedIn,
    bool? isLocked,
    String? token,
    String? refreshToken,
    int? authorId,
    String? username,
    bool? isAdmin,
    bool? requiresPasswordChange,
    DateTime? expiresAt,
    DateTime? refreshExpiresAt,
  }) {
    return AuthorAuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      isLocked: isLocked ?? this.isLocked,
      token: token ?? this.token,
      refreshToken: refreshToken ?? this.refreshToken,
      authorId: authorId ?? this.authorId,
      username: username ?? this.username,
      isAdmin: isAdmin ?? this.isAdmin,
      requiresPasswordChange:
          requiresPasswordChange ?? this.requiresPasswordChange,
      expiresAt: expiresAt ?? this.expiresAt,
      refreshExpiresAt: refreshExpiresAt ?? this.refreshExpiresAt,
    );
  }

  static AuthorAuthState signedOut() =>
      const AuthorAuthState(isLoggedIn: false, isLocked: false, isAdmin: false);
}

final authorAuthProvider =
    StateNotifierProvider<AuthorAuthNotifier, AuthorAuthState>((ref) {
  final repository = ref.read(settingsRepositoryProvider);
  final remote = ref.read(sync_service.remoteEventSourceProvider);
  final storage = ref.read(secureStorageServiceProvider);
  return AuthorAuthNotifier(
      repository: repository, remote: remote, secureStorage: storage);
});

class AuthorAuthNotifier extends StateNotifier<AuthorAuthState> {
  AuthorAuthNotifier({
    required SettingsRepository repository,
    required RemoteEventSource remote,
    required SecureStorageService secureStorage,
    LocalAuthentication? localAuthentication,
    bool restoreSessionOnInit = true,
  })  : _repository = repository,
        _remote = remote,
        _secureStorage = secureStorage,
        _localAuth = localAuthentication ?? LocalAuthentication(),
        super(AuthorAuthState.signedOut()) {
    if (restoreSessionOnInit) {
      unawaited(_restoreSession());
    }
  }

  final SettingsRepository _repository;
  final RemoteEventSource _remote;
  final SecureStorageService _secureStorage;
  final LocalAuthentication _localAuth;

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
      isLocked: false,
      token: storedTokens.accessToken,
      refreshToken: storedTokens.refreshToken,
      authorId: _repository.getAuthorId(),
      username: _repository.getAuthorUsername(),
      isAdmin: _repository.getAuthorIsAdmin(),
      requiresPasswordChange: _repository.getAuthorRequiresPasswordChange(),
      expiresAt: DateTime.tryParse(storedTokens.accessExpiresAt),
      refreshExpiresAt: DateTime.tryParse(storedTokens.refreshExpiresAt),
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
    );
    await _repository.clearLegacyAuthorAuthToken();
    state = AuthorAuthState(
      isLoggedIn: true,
      isLocked: false,
      token: session.accessToken,
      refreshToken: session.refreshToken,
      authorId: session.authorId,
      username: session.username,
      isAdmin: session.isAdmin,
      requiresPasswordChange: session.requiresPasswordChange,
      expiresAt: DateTime.tryParse(session.accessExpiresAt),
      refreshExpiresAt: DateTime.tryParse(session.refreshExpiresAt),
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
    state = state.copyWith(
      requiresPasswordChange: session.requiresPasswordChange,
      isAdmin: session.isAdmin,
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
    final lastBackgroundedAt = _repository.getAuthorLastBackgroundedAt();
    await _repository.setAuthorLastBackgroundedAt(null);
    if (lastBackgroundedAt == null) {
      return;
    }
    final inactiveFor = DateTime.now().toUtc().difference(lastBackgroundedAt);
    if (inactiveFor >= authorLockTimeout) {
      state = state.copyWith(isLocked: true);
    }
  }

  Future<void> unlock() async {
    if (!state.isLoggedIn || !state.isLocked) {
      return;
    }

    final canCheck = await _localAuth.canCheckBiometrics;
    final supported = await _localAuth.isDeviceSupported();
    if (!canCheck && !supported) {
      state = state.copyWith(isLocked: false);
      return;
    }

    final authenticated = await _localAuth.authenticate(
      localizedReason: 'Bitte entsperre den Autorenbereich.',
      options: const AuthenticationOptions(
        biometricOnly: false,
        sensitiveTransaction: true,
        stickyAuth: true,
      ),
    );
    if (!authenticated) {
      throw StateError('Biometrische Entsperrung abgebrochen.');
    }
    state = state.copyWith(isLocked: false);
  }
}
