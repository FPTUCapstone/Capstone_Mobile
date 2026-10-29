import 'package:flutter/foundation.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';

final class AppConfig {
  AppConfig({
    required this.environment,
    required this.apiBaseUrl,
    this.poiCategoryPreview = false,
    this.devSearchV2 = false,
    this.devSearchKey,
    String? webVerificationOrigin,
    String? mapboxAccessToken,
  }) : webVerificationOrigin = webVerificationOrigin == null
           ? null
           : _parseWebVerificationOrigin(webVerificationOrigin, environment),
       mapboxAccessToken = mapboxAccessToken == null
           ? null
           : _parseMapboxAccessToken(mapboxAccessToken);

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
    const devSearchV2 = bool.fromEnvironment('TM70_DEV_SEARCH_V2');
    const devSearchKey = String.fromEnvironment('TM70_DEV_SEARCH_KEY');
    const mapboxAccessTokenValue = String.fromEnvironment(
      'MAPBOX_ACCESS_TOKEN',
    );
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
      devSearchV2: devSearchV2,
      devSearchKey: devSearchKey,
      mapboxAccessToken: mapboxAccessTokenValue.isEmpty
          ? null
          : mapboxAccessTokenValue,
    );
  }

  final Environment environment;
  final Uri apiBaseUrl;
  final Uri? webVerificationOrigin;
  final bool poiCategoryPreview;
  final bool devSearchV2;

  /// Ephemeral lab credential. Never persist or log it; never ship a dev build.
  final String? devSearchKey;
  bool get devSearchEnabled =>
      devSearchV2 &&
      environment != Environment.production &&
      (devSearchKey?.trim().isNotEmpty ?? false);

  /// Public Mapbox token (`pk.`); null disables the map and turn-by-turn
  /// guidance (UC-13 then falls back to an illustration and straight-line
  /// distance).
  final String? mapboxAccessToken;

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

  /// Only public tokens may ship inside the app; a secret (`sk.`) token would
  /// be extractable from the binary.
  static String _parseMapboxAccessToken(String value) {
    final token = value.trim();
    if (!token.startsWith('pk.') || token.contains(RegExp(r'\s'))) {
      throw const FormatException(
        'MAPBOX_ACCESS_TOKEN must be a public Mapbox token starting with "pk.".',
      );
    }
    return token;
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
