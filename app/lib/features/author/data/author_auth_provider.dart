import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../../core/services/sync_service.dart' as sync_service;
import '../../events/data/remote_event_source.dart';
import '../../settings/data/settings_repository.dart';

const Duration authorLockTimeout = Duration(seconds: 60);

class AuthorAuthState {
  const AuthorAuthState({
    required this.isLoggedIn,
    required this.isLocked,
    this.token,
    this.authorId,
    this.username,
    this.isAdmin = false,
    this.requiresPasswordChange = false,
  });

  final bool isLoggedIn;
  final bool isLocked;
  final String? token;
  final int? authorId;
  final String? username;
  final bool isAdmin;
  final bool requiresPasswordChange;

  AuthorAuthState copyWith({
    bool? isLoggedIn,
    bool? isLocked,
    String? token,
    int? authorId,
    String? username,
    bool? isAdmin,
    bool? requiresPasswordChange,
  }) {
    return AuthorAuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      isLocked: isLocked ?? this.isLocked,
      token: token ?? this.token,
      authorId: authorId ?? this.authorId,
      username: username ?? this.username,
      isAdmin: isAdmin ?? this.isAdmin,
      requiresPasswordChange: requiresPasswordChange ?? this.requiresPasswordChange,
    );
  }

  static AuthorAuthState signedOut() =>
      const AuthorAuthState(isLoggedIn: false, isLocked: false, isAdmin: false);
}

final authorAuthProvider = StateNotifierProvider<AuthorAuthNotifier, AuthorAuthState>((ref) {
  final repository = ref.read(settingsRepositoryProvider);
  final remote = ref.read(sync_service.remoteEventSourceProvider);
  return AuthorAuthNotifier(repository: repository, remote: remote);
});

class AuthorAuthNotifier extends StateNotifier<AuthorAuthState> {
  AuthorAuthNotifier({
    required SettingsRepository repository,
    required RemoteEventSource remote,
    LocalAuthentication? localAuthentication,
  }) : _repository = repository,
       _remote = remote,
       _localAuth = localAuthentication ?? LocalAuthentication(),
       super(_loadInitialState(repository));

  final SettingsRepository _repository;
  final RemoteEventSource _remote;
  final LocalAuthentication _localAuth;

  static AuthorAuthState _loadInitialState(SettingsRepository repository) {
    final token = repository.getAuthorAuthToken();
    if (token == null || token.isEmpty) {
      return AuthorAuthState.signedOut();
    }
    return AuthorAuthState(
      isLoggedIn: true,
      isLocked: false,
      token: token,
      authorId: repository.getAuthorId(),
      username: repository.getAuthorUsername(),
      isAdmin: repository.getAuthorIsAdmin(),
      requiresPasswordChange: repository.getAuthorRequiresPasswordChange(),
    );
  }

  Future<void> login(String username, String password) async {
    final session = await _remote.loginAuthor(username: username, password: password);
    await _repository.saveAuthorSession(
      token: session.token,
      authorId: session.authorId,
      username: session.username,
      isAdmin: session.isAdmin,
      requiresPasswordChange: session.requiresPasswordChange,
    );
    state = AuthorAuthState(
      isLoggedIn: true,
      isLocked: false,
      token: session.token,
      authorId: session.authorId,
      username: session.username,
      isAdmin: session.isAdmin,
      requiresPasswordChange: session.requiresPasswordChange,
    );
  }

  Future<void> logout() async {
    final token = state.token;
    if (token != null && token.isNotEmpty) {
      await _remote.logoutAuthor(token: token);
    }
    await _repository.clearAuthorSession();
    state = AuthorAuthState.signedOut();
  }

  Future<void> refreshSession() async {
    final token = state.token;
    if (token == null || token.isEmpty) {
      return;
    }
    final session = await _remote.fetchAuthorSession(token: token);
    await _repository.setAuthorRequiresPasswordChange(session.requiresPasswordChange);
    await _repository.setAuthorIsAdmin(session.isAdmin);
    state = state.copyWith(
      requiresPasswordChange: session.requiresPasswordChange,
      isAdmin: session.isAdmin,
    );
  }

  Future<void> changePassword({String? oldPassword, required String newPassword}) async {
    final token = state.token;
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
