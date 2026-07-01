import 'package:dpsg_news_app/core/services/logging_env.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses fallback values for invalid or missing numbers', () async {
    dotenv.loadFromString(envString: 'LOG_MAX_DAYS=0\nLOG_MAX_SIZE_MB=abc');

    expect(LoggingEnv.maxDays, 7);
    expect(LoggingEnv.maxSizeMb, 1);
    expect(LoggingEnv.maxSizeBytes, 1024 * 1024);
  });

  test('uses configured positive integer values', () async {
    dotenv.loadFromString(envString: 'LOG_MAX_DAYS=14\nLOG_MAX_SIZE_MB=3');

    expect(LoggingEnv.maxDays, 14);
    expect(LoggingEnv.maxSizeMb, 3);
    expect(LoggingEnv.maxSizeBytes, 3 * 1024 * 1024);
  });
}
