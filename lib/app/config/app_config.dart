import 'package:flutter/foundation.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';

final class AppConfig {
  const AppConfig({
    required this.environment,
    required this.apiBaseUrl,
    this.poiCategoryPreview = false,
  });

  factory AppConfig.fromEnvironment() {
    const environmentValue = String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'development',
    );
    const apiBaseUrlValue = String.fromEnvironment('API_BASE_URL');
    const poiCategoryPreview = bool.fromEnvironment('POI_CATEGORY_PREVIEW');
    final resolvedApiBaseUrl = apiBaseUrlValue.isNotEmpty
        ? apiBaseUrlValue
        : _defaultApiBaseUrl();

    return AppConfig(
      environment: Environment.fromValue(environmentValue),
      apiBaseUrl: _parseBaseUrl(resolvedApiBaseUrl),
      poiCategoryPreview: poiCategoryPreview,
    );
  }

  final Environment environment;
  final Uri apiBaseUrl;
  final bool poiCategoryPreview;

  bool get enableNetworkLogs => environment != Environment.production;
  bool get categoryPreviewEnabled =>
      poiCategoryPreview && environment != Environment.production;

  static String _defaultApiBaseUrl() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5000';
    }
    return 'https://api.example.invalid';
  }

  @visibleForTesting
  static Uri parseBaseUrl(String value) => _parseBaseUrl(value);

  static Uri _parseBaseUrl(String value) {
    if (value.contains(RegExp(r'\s'))) {
      throw FormatException('API_BASE_URL must not contain whitespace.', value);
    }
    final uri = Uri.tryParse(value);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      throw FormatException(
        'API_BASE_URL must be an absolute HTTP or HTTPS URL with a non-empty host.',
        value,
      );
    }
    return uri;
  }
}
