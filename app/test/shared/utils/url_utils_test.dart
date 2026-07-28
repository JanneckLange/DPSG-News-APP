import 'package:flutter_test/flutter_test.dart';
import 'package:dpsg_news_app/shared/utils/url_utils.dart';

void main() {
  group('isHttpOrHttpsUri', () {
    test('accepts https URIs', () {
      expect(isHttpOrHttpsUri(Uri.parse('https://example.org')), isTrue);
    });

    test('accepts http URIs', () {
      expect(isHttpOrHttpsUri(Uri.parse('http://example.org')), isTrue);
    });

    test('rejects javascript scheme', () {
      expect(isHttpOrHttpsUri(Uri.parse('javascript:alert(1)')), isFalse);
    });

    test('rejects file scheme', () {
      expect(isHttpOrHttpsUri(Uri.parse('file:///etc/passwd')), isFalse);
    });

    test('rejects intent scheme', () {
      expect(isHttpOrHttpsUri(Uri.parse('intent://foo#Intent;scheme=https;end')), isFalse);
    });

    test('rejects an empty scheme', () {
      expect(isHttpOrHttpsUri(Uri.parse('www.example.org')), isFalse);
    });
  });

  group('looksLikeMailto', () {
    test('accepts an explicit mailto: prefix', () {
      expect(looksLikeMailto('mailto:max@example.org'), isTrue);
    });

    test('accepts a bare email address without scheme', () {
      expect(looksLikeMailto('max@example.org'), isTrue);
    });

    test('rejects an http(s) URL even if it contains @ in the userinfo part', () {
      expect(looksLikeMailto('https://user@example.org'), isFalse);
    });

    test('rejects a plain https URL without @', () {
      expect(looksLikeMailto('https://example.org'), isFalse);
    });
  });

  group('extractMailtoAddress', () {
    test('strips the mailto: prefix', () {
      expect(extractMailtoAddress('mailto:max@example.org'), 'max@example.org');
    });

    test('returns a bare address unchanged', () {
      expect(extractMailtoAddress('max@example.org'), 'max@example.org');
    });

    test('strips query parameters', () {
      expect(
        extractMailtoAddress('mailto:max@example.org?subject=Hallo'),
        'max@example.org',
      );
    });
  });
}
