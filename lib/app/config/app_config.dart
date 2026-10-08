import 'package:flutter/foundation.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';

final class AppConfig {
  AppConfig({
    required this.environment,
    required this.apiBaseUrl,
    this.poiCategoryPreview = false,
    String? webVerificationOrigin,
  }) : webVerificationOrigin = webVerificationOrigin == null
           ? null
           : _parseWebVerificationOrigin(webVerificationOrigin, environment);

  factory AppConfig.fromEnvironment() {
    const environmentValue = String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'development',
    );
    const apiBaseUrlValue = String.fromEnvironment('API_BASE_URL');
    const webVerificationOriginValue = String.fromEnvironment(
      'WEB_VERIFICATION_ORIGIN',
    );
    const poiCategoryPreview = bool.fromEnvironment('POI_CATEGORY_PREVIEW');
    final resolvedApiBaseUrl = apiBaseUrlValue.isNotEmpty
        ? apiBaseUrlValue
        : _defaultApiBaseUrl();

    return AppConfig(
      environment: Environment.fromValue(environmentValue),
      apiBaseUrl: _parseBaseUrl(resolvedApiBaseUrl),
      webVerificationOrigin: webVerificationOriginValue.isEmpty
          ? null
          : webVerificationOriginValue,
      poiCategoryPreview: poiCategoryPreview,
    );
  }

  final Environment environment;
  final Uri apiBaseUrl;
  final Uri? webVerificationOrigin;
  final bool poiCategoryPreview;

  /// Fails closed until an actual Web origin is configured for UC-02.
  Uri requireOperatorVerificationContinueUrl() {
    final origin = webVerificationOrigin;
    if (origin == null) {
      throw StateError('WEB_VERIFICATION_ORIGIN is not configured.');
    }
    return origin.resolve('/verify-email?flow=operator-mobile');
  }

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

  static Uri _parseWebVerificationOrigin(
    String value,
    Environment environment,
  ) {
    final uri = Uri.tryParse(value);
    final isLocalHost =
        uri != null &&
        (uri.host == 'localhost' ||
            uri.host == '127.0.0.1' ||
            uri.host == '::1');
    final isAllowedScheme =
        uri != null &&
        (uri.scheme == 'https' ||
            (uri.scheme == 'http' &&
                isLocalHost &&
                environment != Environment.production));
    if (value.contains(RegExp(r'\s')) ||
        uri == null ||
        !isAllowedScheme ||
        uri.host.isEmpty ||
        uri.host.endsWith('.invalid') ||
        uri.userInfo.isNotEmpty ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw FormatException(
        'WEB_VERIFICATION_ORIGIN must be a valid HTTPS origin '
        '(local HTTP is allowed only in development or staging).',
      );
    }
    return uri.replace(path: '');
  }
}
