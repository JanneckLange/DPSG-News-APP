import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final secureStorageServiceProvider = Provider<SecureStorageService>((_) {
  return SecureStorageService(const FlutterSecureStorage());
});

class SecureStorageService {
  SecureStorageService(this._storage);

  static const String _authorAccessTokenKey = 'author_access_token';
  static const String _authorRefreshTokenKey = 'author_refresh_token';
  static const String _authorAccessExpiresAtKey = 'author_access_expires_at';
  static const String _authorRefreshExpiresAtKey = 'author_refresh_expires_at';

  final FlutterSecureStorage _storage;

  Future<void> saveAuthorTokens({
    required String accessToken,
    required String refreshToken,
    required String accessExpiresAt,
    required String refreshExpiresAt,
  }) async {
    await Future.wait([
      _storage.write(key: _authorAccessTokenKey, value: accessToken),
      _storage.write(key: _authorRefreshTokenKey, value: refreshToken),
      _storage.write(key: _authorAccessExpiresAtKey, value: accessExpiresAt),
      _storage.write(key: _authorRefreshExpiresAtKey, value: refreshExpiresAt),
    ]);
  }

  Future<AuthorTokenBundle?> readAuthorTokens() async {
    final values = await Future.wait([
      _storage.read(key: _authorAccessTokenKey),
      _storage.read(key: _authorRefreshTokenKey),
      _storage.read(key: _authorAccessExpiresAtKey),
      _storage.read(key: _authorRefreshExpiresAtKey),
    ]);
    final accessToken = values[0];
    final refreshToken = values[1];
    final accessExpiresAt = values[2];
    final refreshExpiresAt = values[3];
    if (accessToken == null ||
        accessToken.isEmpty ||
        refreshToken == null ||
        refreshToken.isEmpty ||
        accessExpiresAt == null ||
        accessExpiresAt.isEmpty ||
        refreshExpiresAt == null ||
        refreshExpiresAt.isEmpty) {
      return null;
    }
    return AuthorTokenBundle(
      accessToken: accessToken,
      refreshToken: refreshToken,
      accessExpiresAt: accessExpiresAt,
      refreshExpiresAt: refreshExpiresAt,
    );
  }

  Future<void> clearAuthorTokens() async {
    await Future.wait([
      _storage.delete(key: _authorAccessTokenKey),
      _storage.delete(key: _authorRefreshTokenKey),
      _storage.delete(key: _authorAccessExpiresAtKey),
      _storage.delete(key: _authorRefreshExpiresAtKey),
    ]);
  }
}

class AuthorTokenBundle {
  AuthorTokenBundle({
    required this.accessToken,
    required this.refreshToken,
    required this.accessExpiresAt,
    required this.refreshExpiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final String accessExpiresAt;
  final String refreshExpiresAt;
}
