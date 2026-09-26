import 'dart:io';

enum AppEnvironment { development, production }

class AppConfig {
  static const String _environment = String.fromEnvironment(
    'ENV',
    defaultValue: 'development',
  );

  static AppEnvironment get environment {
    return _environment == 'production'
        ? AppEnvironment.production
        : AppEnvironment.development;
  }

  static String get apiBaseUrl {
    if (environment == AppEnvironment.production) {
      return 'https://papatzoa.onrender.com/api';
    }

    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000/api';
    }

    return 'http://127.0.0.1:8000/api';
  }

  static bool get isDevelopment => environment == AppEnvironment.development;

  static bool get isProduction => environment == AppEnvironment.production;
}
