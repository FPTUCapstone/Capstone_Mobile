import 'package:flutter_test/flutter_test.dart';

import '../../tool/validate_api_base_url.dart';

void main() {
  group('isValidApiBaseUrl unit tests', () {
    test('returns true for valid HTTP and HTTPS URLs with host', () {
      final validUrls = [
        'https://example.com',
        'https://example.com/',
        'https://example.com/api',
        'https://example.com/api/v1/pois',
        'http://10.0.2.2:5000',
        'https://capstonebe-production-1df1.up.railway.app',
        'https://example.com?query=value',
        'https://example.com#fragment',
      ];

      for (final url in validUrls) {
        expect(isValidApiBaseUrl(url), isTrue, reason: 'Expected valid: $url');
      }
    });

    test('returns false for empty or whitespace-only inputs', () {
      final invalidUrls = ['', '   ', '\t', '\n'];

      for (final url in invalidUrls) {
        expect(
          isValidApiBaseUrl(url),
          isFalse,
          reason: 'Expected invalid: "$url"',
        );
      }
    });

    test('returns false for URLs missing host or using invalid schemes', () {
      final invalidUrls = [
        'https://',
        'http://',
        'https:///',
        'https://?query',
        'https://#fragment',
        'https:// example.com',
        'ftp://example.com',
        'example.com',
        '://example.com',
        'http://   ',
      ];

      for (final url in invalidUrls) {
        expect(
          isValidApiBaseUrl(url),
          isFalse,
          reason: 'Expected invalid: "$url"',
        );
      }
    });
  });

  group('runValidateApiBaseUrl CLI tests', () {
    test('returns exit code 1 when arguments are missing', () {
      final err = StringBuffer();
      final out = StringBuffer();

      final exitCode = runValidateApiBaseUrl([], out: out, err: err);

      expect(exitCode, 1);
      expect(err.toString(), contains('API_BASE_URL argument is missing'));
      expect(out.toString(), isEmpty);
    });

    test('returns exit code 1 for invalid URL (https://?query)', () {
      final err = StringBuffer();
      final out = StringBuffer();

      final exitCode = runValidateApiBaseUrl(
        ['https://?query'],
        out: out,
        err: err,
      );

      expect(exitCode, 1);
      expect(
        err.toString(),
        contains('must be a valid HTTP or HTTPS URL with a non-empty host'),
      );
      expect(out.toString(), isEmpty);
    });

    test('returns exit code 1 for invalid URL (https://)', () {
      final err = StringBuffer();
      final out = StringBuffer();

      final exitCode = runValidateApiBaseUrl(['https://'], out: out, err: err);

      expect(exitCode, 1);
      expect(
        err.toString(),
        contains('must be a valid HTTP or HTTPS URL with a non-empty host'),
      );
      expect(out.toString(), isEmpty);
    });

    test('returns exit code 0 for valid URL', () {
      final err = StringBuffer();
      final out = StringBuffer();

      final exitCode = runValidateApiBaseUrl(
        ['https://capstonebe-production-1df1.up.railway.app'],
        out: out,
        err: err,
      );

      expect(exitCode, 0);
      expect(out.toString(), contains('API_BASE_URL is valid.'));
      expect(err.toString(), isEmpty);
    });
  });
}
