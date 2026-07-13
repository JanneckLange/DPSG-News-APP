import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:dpsg_news_app/core/config/app_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reads Wiredash and PostHog config from dotenv assets', () async {
    await dotenv.load(fileName: '.env');

    expect(AppConfig.wiredashProjectId, isNotEmpty);
    expect(AppConfig.wiredashSecret, isNotEmpty);
    expect(AppConfig.hasWiredashConfig, isTrue);
    expect(AppConfig.posthogApiKey, isNotEmpty);
    expect(AppConfig.posthogProjectId, isNotEmpty);
    expect(AppConfig.hasPosthogConfig, isTrue);
  });
}
