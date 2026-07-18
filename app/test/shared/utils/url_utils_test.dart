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
}
