import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/constants/app_constants.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/helpers/session_identity_helper.dart';

void main() {
  String buildTestJwt(Map<String, dynamic> claims) {
    final header = base64Url.encode(
      utf8.encode(json.encode({'alg': 'HS256', 'typ': 'JWT'})),
    );
    final payload = base64Url.encode(utf8.encode(json.encode(claims)));
    const signature = 'fake_signature';
    return '$header.$payload.$signature';
  }

  group('SessionIdentityHelper.parseUserIdFromJwt', () {
    test('parses integer userId from "sub" claim', () {
      final jwt = buildTestJwt({'sub': '101'});
      expect(SessionIdentityHelper.parseUserIdFromJwt(jwt), 101);
    });

    test('parses integer userId from numeric "sub" claim', () {
      final jwt = buildTestJwt({'sub': 202});
      expect(SessionIdentityHelper.parseUserIdFromJwt(jwt), 202);
    });

    test('parses integer userId from "nameid" claim', () {
      final jwt = buildTestJwt({'nameid': '303'});
      expect(SessionIdentityHelper.parseUserIdFromJwt(jwt), 303);
    });

    test('parses integer userId from full schema URI nameidentifier claim', () {
      final jwt = buildTestJwt({
        'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier':
            '404',
      });
      expect(SessionIdentityHelper.parseUserIdFromJwt(jwt), 404);
    });

    test('returns null for null, empty, or whitespace tokens', () {
      expect(SessionIdentityHelper.parseUserIdFromJwt(null), isNull);
      expect(SessionIdentityHelper.parseUserIdFromJwt(''), isNull);
      expect(SessionIdentityHelper.parseUserIdFromJwt('   '), isNull);
    });

    test('returns null for malformed tokens lacking proper parts', () {
      expect(SessionIdentityHelper.parseUserIdFromJwt('not-a-jwt'), isNull);
      expect(SessionIdentityHelper.parseUserIdFromJwt('singlepart'), isNull);
    });

    test('returns null for corrupted base64 or non-JSON payloads', () {
      expect(
        SessionIdentityHelper.parseUserIdFromJwt(
          'header.!!!invalid-base64!!!.sig',
        ),
        isNull,
      );
    });

    test(
      'returns null when payload does not contain a user identifier claim',
      () {
        final jwt = buildTestJwt({
          'role': 'Traveler',
          'email': 'test@example.com',
        });
        expect(SessionIdentityHelper.parseUserIdFromJwt(jwt), isNull);
      },
    );

    test(
      'returns null when user identifier claim cannot be parsed as integer',
      () {
        final jwt = buildTestJwt({'sub': 'not-an-integer'});
        expect(SessionIdentityHelper.parseUserIdFromJwt(jwt), isNull);
      },
    );
  });

  group('SessionIdentityHelper.getCurrentUserId', () {
    test('retrieves and parses userId from SecureStorageService', () async {
      final storage = _FakeSecureStorage();
      final jwt = buildTestJwt({'sub': '777'});
      await storage.write(AppConstants.accessTokenKey, jwt);

      final result = await SessionIdentityHelper.getCurrentUserId(storage);
      expect(result, 777);
    });

    test('returns null when access token is not stored', () async {
      final storage = _FakeSecureStorage();

      final result = await SessionIdentityHelper.getCurrentUserId(storage);
      expect(result, isNull);
    });

    test('returns null when storage throws exception (fails closed)', () async {
      final storage = _FailingSecureStorage();

      final result = await SessionIdentityHelper.getCurrentUserId(storage);
      expect(result, isNull);
    });
  });
}

final class _FakeSecureStorage implements SecureStorageService {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async {
    _data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    _data.clear();
  }
}

final class _FailingSecureStorage implements SecureStorageService {
  @override
  Future<String?> read(String key) async => throw Exception('Storage error');

  @override
  Future<void> write(String key, String value) async =>
      throw Exception('Storage error');

  @override
  Future<void> delete(String key) async => throw Exception('Storage error');

  @override
  Future<void> deleteAll() async => throw Exception('Storage error');
}
