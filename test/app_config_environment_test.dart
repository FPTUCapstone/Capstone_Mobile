import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('Android defaults to the local backend through the emulator host', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    final config = AppConfig.fromEnvironment();

    expect(config.apiBaseUrl, Uri.parse('http://10.0.2.2:5000'));
    expect(
      config.apiBaseUrl.resolve('/api/v1/auth/login'),
      Uri.parse('http://10.0.2.2:5000/api/v1/auth/login'),
    );
  });

  test('non-Android platforms keep the safe placeholder default', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;

    expect(
      AppConfig.fromEnvironment().apiBaseUrl,
      Uri.parse('https://api.example.invalid'),
    );
  });

  test('does not enable category preview in production', () {
    final config = AppConfig(
      environment: Environment.production,
      apiBaseUrl: Uri.parse('https://api.example.invalid'),
      poiCategoryPreview: true,
    );

    expect(config.categoryPreviewEnabled, isFalse);
  });

  group('AppConfig.parseBaseUrl', () {
    test('accepts valid HTTP/HTTPS URLs with non-empty host', () {
      expect(
        AppConfig.parseBaseUrl('https://example.com'),
        Uri.parse('https://example.com'),
      );
      expect(
        AppConfig.parseBaseUrl('http://10.0.2.2:5000'),
        Uri.parse('http://10.0.2.2:5000'),
      );
      expect(
        AppConfig.parseBaseUrl(
          'https://capstonebe-production-1df1.up.railway.app',
        ),
        Uri.parse('https://capstonebe-production-1df1.up.railway.app'),
      );
    });

    test('rejects URLs missing a host or using unsupported schemes', () {
      expect(() => AppConfig.parseBaseUrl('https://'), throwsFormatException);
      expect(() => AppConfig.parseBaseUrl('http://'), throwsFormatException);
      expect(() => AppConfig.parseBaseUrl('https:///'), throwsFormatException);
      expect(
        () => AppConfig.parseBaseUrl('https://?query'),
        throwsFormatException,
      );
      expect(
        () => AppConfig.parseBaseUrl('https://#fragment'),
        throwsFormatException,
      );
      expect(
        () => AppConfig.parseBaseUrl('https:// example.com'),
        throwsFormatException,
      );
      expect(
        () => AppConfig.parseBaseUrl('ftp://example.com'),
        throwsFormatException,
      );
      expect(
        () => AppConfig.parseBaseUrl('example.com'),
        throwsFormatException,
      );
      expect(
        () => AppConfig.parseBaseUrl('://example.com'),
        throwsFormatException,
      );
    });
  });
}
