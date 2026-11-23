import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/constants/app_constants.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/auth/data/datasources/offline_trip_identity_source.dart';

void main() {
  test(
    'retains only a valid backend Traveler identity and online expiry is separate',
    () async {
      final storage = MemoryOfflineStorage();
      final source = OfflineTripIdentitySource(storage);
      final token = offlineJwt(7);
      storage.values.addAll({
        AppConstants.accessTokenKey: token,
        AppConstants.sessionRoleKey: 'traveler',
      });
      await source.enableForSession(
        userId: 7,
        accessToken: token,
        isTraveler: true,
      );
      expect(await source.currentOwnerId(), 7);
      expect(await source.currentOnlineOwnerId(), 7);
      final generation = await source.currentSessionKey();
      expect(generation, isNotEmpty);
      storage.values.remove(AppConstants.accessTokenKey);
      storage.values.remove(AppConstants.sessionRoleKey);
      expect(await source.currentOwnerId(), 7);
      expect(await source.currentOnlineOwnerId(), isNull);
      expect(await source.currentSessionKey(), generation);
    },
  );

  test(
    'expired token permits local identity but cannot authorize downloads',
    () async {
      final storage = MemoryOfflineStorage();
      final source = OfflineTripIdentitySource(storage);
      final token = offlineJwt(7, expired: true);
      storage.values.addAll({
        AppConstants.accessTokenKey: token,
        AppConstants.sessionRoleKey: 'traveler',
      });
      await source.enableForSession(
        userId: 7,
        accessToken: token,
        isTraveler: true,
      );
      expect(await source.currentOwnerId(), 7);
      expect(await source.currentOnlineOwnerId(), isNull);
    },
  );

  test(
    'logout revokes local identity and new account rotates session key',
    () async {
      final storage = MemoryOfflineStorage();
      final source = OfflineTripIdentitySource(storage);
      await source.enableForSession(
        userId: 7,
        accessToken: offlineJwt(7),
        isTraveler: true,
      );
      final first = await source.currentSessionKey();
      expect(await source.disableForLogout(), isTrue);
      expect(await source.currentOwnerId(), isNull);
      await source.enableForSession(
        userId: 8,
        accessToken: offlineJwt(8),
        isTraveler: true,
      );
      expect(await source.currentOwnerId(), 8);
      expect(await source.currentSessionKey(), isNot(first));
    },
  );

  test(
    'different JWT or operator cannot expose retained traveler files',
    () async {
      final storage = MemoryOfflineStorage();
      final source = OfflineTripIdentitySource(storage);
      await source.enableForSession(
        userId: 7,
        accessToken: offlineJwt(7),
        isTraveler: true,
      );
      storage.values.addAll({
        AppConstants.accessTokenKey: offlineJwt(8),
        AppConstants.sessionRoleKey: 'traveler',
      });
      expect(await source.currentOwnerId(), isNull);
      storage.values[AppConstants.sessionRoleKey] = 'tourOperator';
      expect(await source.currentOwnerId(), isNull);
    },
  );

  test(
    'mismatched backend session and unreadable storage fail closed',
    () async {
      final storage = MemoryOfflineStorage();
      final source = OfflineTripIdentitySource(storage);
      await source.enableForSession(
        userId: 7,
        accessToken: offlineJwt(8),
        isTraveler: true,
      );
      expect(await source.currentOwnerId(), isNull);
      storage.failReads = true;
      expect(await source.currentOwnerId(), isNull);
      expect(await source.disableForLogout(), isFalse);
    },
  );

  test(
    'failed logout mutations cannot falsely claim offline identity revoked',
    () async {
      final storage = MemoryOfflineStorage();
      final source = OfflineTripIdentitySource(storage);
      await source.enableForSession(
        userId: 7,
        accessToken: offlineJwt(7),
        isTraveler: true,
      );
      storage.failMutations = true;
      expect(await source.disableForLogout(), isFalse);
      expect(await source.currentOwnerId(), 7);
    },
  );

  test(
    'expired same-account access may use the existing refresh pipeline only when renewable',
    () async {
      final storage = MemoryOfflineStorage();
      final token = offlineJwt(7, expired: true);
      final source = OfflineTripIdentitySource(storage);
      await source.enableForSession(
        userId: 7,
        accessToken: token,
        isTraveler: true,
      );
      storage.values.addAll({
        AppConstants.accessTokenKey: token,
        AppConstants.sessionRoleKey: 'traveler',
        AppConstants.keepSignedInKey: 'true',
        AppConstants.refreshTokenKey: 'refresh',
      });
      expect(await source.currentOnlineOwnerId(), 7);
      storage.values.remove(AppConstants.refreshTokenKey);
      expect(await source.currentOnlineOwnerId(), isNull);
      storage.values[AppConstants.refreshTokenKey] = 'refresh';
      storage.values[AppConstants.keepSignedInKey] = 'false';
      expect(await source.currentOnlineOwnerId(), isNull);
    },
  );
}

String offlineJwt(int id, {bool expired = false}) {
  final payload = base64Url
      .encode(
        utf8.encode(
          jsonEncode({
            'sub': '$id',
            'exp':
                DateTime.now()
                    .toUtc()
                    .add(Duration(hours: expired ? -1 : 1))
                    .millisecondsSinceEpoch ~/
                1000,
          }),
        ),
      )
      .replaceAll('=', '');
  return 'eyJhbGciOiJIUzI1NiJ9.$payload.signature';
}

class MemoryOfflineStorage implements SecureStorageService {
  final values = <String, String>{};
  bool failReads = false;
  bool failMutations = false;
  bool failOfflineReads = false;
  @override
  Future<String?> read(String key) async {
    if (failReads || (failOfflineReads && key.startsWith('offline_trip_'))) {
      throw StateError('Unavailable');
    }
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (failMutations) throw StateError('Unavailable');
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    if (failMutations) throw StateError('Unavailable');
    values.remove(key);
  }

  @override
  Future<void> deleteAll() async => values.clear();
}
