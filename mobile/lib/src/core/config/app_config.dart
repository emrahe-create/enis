import 'package:flutter/foundation.dart';

class AppConfig {
  const AppConfig._();

  static const environment =
      String.fromEnvironment('APP_ENV', defaultValue: 'development');
  static const _mockFallbackRequested = bool.fromEnvironment(
    'ALLOW_MOCK_FALLBACK',
    defaultValue: false,
  );

  static bool get isProduction => environment.toLowerCase() == 'production';

  static bool get allowMockFallback {
    return kDebugMode && !isProduction && _mockFallbackRequested;
  }
}
