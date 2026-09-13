import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';

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
}
