import 'package:flutter/foundation.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';

final class AppConfig {
  const AppConfig({required this.environment, required this.apiBaseUrl});

  factory AppConfig.fromEnvironment() {
    const environmentValue = String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'development',
    );
    const apiBaseUrlValue = String.fromEnvironment('API_BASE_URL');
    final resolvedApiBaseUrl = apiBaseUrlValue.isNotEmpty
        ? apiBaseUrlValue
        : _defaultApiBaseUrl();

    return AppConfig(
      environment: Environment.fromValue(environmentValue),
      apiBaseUrl: _parseBaseUrl(resolvedApiBaseUrl),
    );
  }

  final Environment environment;
  final Uri apiBaseUrl;

  bool get enableNetworkLogs => environment != Environment.production;

  static String _defaultApiBaseUrl() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5000';
    }
    return 'https://api.example.invalid';
  }

  static Uri _parseBaseUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      throw FormatException('API_BASE_URL must be an absolute URL.', value);
    }
    return uri;
  }
}
