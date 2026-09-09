import 'package:trip_mate_mobile/app/config/environment.dart';

final class AppConfig {
  const AppConfig({required this.environment, required this.apiBaseUrl});

  factory AppConfig.fromEnvironment() {
    const environmentValue = String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'development',
    );
    const apiBaseUrlValue = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://localhost:5021',
    );

    return AppConfig(
      environment: Environment.fromValue(environmentValue),
      apiBaseUrl: _parseBaseUrl(apiBaseUrlValue),
    );
  }

  final Environment environment;
  final Uri apiBaseUrl;

  bool get enableNetworkLogs => environment != Environment.production;

  static Uri _parseBaseUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      throw FormatException('API_BASE_URL must be an absolute URL.', value);
    }
    return uri;
  }
}
