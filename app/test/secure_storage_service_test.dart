import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dpsg_news_app/core/services/secure_storage_service.dart';

class _FakeFlutterSecureStorage extends FlutterSecureStorage {
  _FakeFlutterSecureStorage(this._data) : super();

  final Map<String, String> _data;

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _data.remove(key);
    } else {
      _data[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _data[key];

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _data.remove(key);
  }
}

void main() {
  late Map<String, String> backingStore;
  late SecureStorageService service;

  setUp(() {
    backingStore = <String, String>{};
    service = SecureStorageService(_FakeFlutterSecureStorage(backingStore));
  });

  test('readAuthorTokens returns null when nothing has been saved yet',
      () async {
    expect(await service.readAuthorTokens(), isNull);
  });

  test(
      'saveAuthorTokens persists all four values so they can be read back exactly',
      () async {
    await service.saveAuthorTokens(
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
      accessExpiresAt: '2026-01-01T00:00:00.000Z',
      refreshExpiresAt: '2026-01-08T00:00:00.000Z',
    );

    final tokens = await service.readAuthorTokens();

    expect(tokens, isNotNull);
    expect(tokens!.accessToken, 'access-1');
    expect(tokens.refreshToken, 'refresh-1');
    expect(tokens.accessExpiresAt, '2026-01-01T00:00:00.000Z');
    expect(tokens.refreshExpiresAt, '2026-01-08T00:00:00.000Z');
  });

  test(
      'readAuthorTokens returns null when only some of the four values are present',
      () async {
    backingStore['author_access_token'] = 'access-1';
    // refresh token and both expiry timestamps are missing.

    expect(await service.readAuthorTokens(), isNull);
  });

  test('readAuthorTokens returns null when a stored value is an empty string',
      () async {
    await service.saveAuthorTokens(
      accessToken: '',
      refreshToken: 'refresh-1',
      accessExpiresAt: '2026-01-01T00:00:00.000Z',
      refreshExpiresAt: '2026-01-08T00:00:00.000Z',
    );

    expect(await service.readAuthorTokens(), isNull);
  });

  test('clearAuthorTokens removes all four stored values', () async {
    await service.saveAuthorTokens(
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
      accessExpiresAt: '2026-01-01T00:00:00.000Z',
      refreshExpiresAt: '2026-01-08T00:00:00.000Z',
    );

    await service.clearAuthorTokens();

    expect(await service.readAuthorTokens(), isNull);
    expect(backingStore, isEmpty);
  });

  test('saveAuthorTokens overwrites previously stored values', () async {
    await service.saveAuthorTokens(
      accessToken: 'old-access',
      refreshToken: 'old-refresh',
      accessExpiresAt: '2026-01-01T00:00:00.000Z',
      refreshExpiresAt: '2026-01-08T00:00:00.000Z',
    );
    await service.saveAuthorTokens(
      accessToken: 'new-access',
      refreshToken: 'new-refresh',
      accessExpiresAt: '2026-02-01T00:00:00.000Z',
      refreshExpiresAt: '2026-02-08T00:00:00.000Z',
    );

    final tokens = await service.readAuthorTokens();

    expect(tokens!.accessToken, 'new-access');
    expect(tokens.refreshToken, 'new-refresh');
    expect(tokens.accessExpiresAt, '2026-02-01T00:00:00.000Z');
    expect(tokens.refreshExpiresAt, '2026-02-08T00:00:00.000Z');
  });
}
