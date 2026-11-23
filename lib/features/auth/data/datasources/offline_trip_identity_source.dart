import 'dart:convert';

import 'package:trip_mate_mobile/core/constants/app_constants.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/auth/domain/services/offline_access_identity.dart';
import 'package:uuid/uuid.dart';

/// Reads only credentials already persisted from a backend-issued session.
/// Parsing these claims is local cache partitioning, never server authorization.
final class OfflineTripIdentitySource implements OfflineAccessIdentity {
  OfflineTripIdentitySource(this.storage, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  static const ownerKey = 'offline_trip_owner_id';
  static const enabledKey = 'offline_trip_access_enabled';
  static const generationKey = 'offline_trip_session_generation';
  final SecureStorageService storage;
  final DateTime Function() _now;

  @override
  Future<int?> currentOwnerId() => storage.withSessionLock(_currentOwnerId);

  @override
  Future<int?> ownerWhileSessionLocked() => _currentOwnerId();

  Future<int?> _currentOwnerId() async {
    try {
      if (await storage.read(enabledKey) != 'true') return null;
      final owner = int.tryParse(await storage.read(ownerKey) ?? '');
      final generation = await storage.read(generationKey);
      if (owner == null ||
          owner <= 0 ||
          generation == null ||
          generation.isEmpty) {
        return null;
      }
      final role = await storage.read(AppConstants.sessionRoleKey);
      if (role != null && role != 'traveler') return null;
      final token = await storage.read(AppConstants.accessTokenKey);
      if (token != null && token.isNotEmpty && tokenOwnerId(token) != owner) {
        return null;
      }
      return owner;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<int?> currentOnlineOwnerId() => storage.withSessionLock(() async {
    final owner = await _currentOwnerId();
    if (owner == null) return null;
    try {
      final role = await storage.read(AppConstants.sessionRoleKey);
      final token = await storage.read(AppConstants.accessTokenKey);
      final expiry = _claims(token)?['exp'];
      if (role != 'traveler' ||
          tokenOwnerId(token) != owner ||
          expiry is! num) {
        return null;
      }
      if (tokenHasExpired(token)) {
        final keepSignedIn = await storage.read(AppConstants.keepSignedInKey);
        final refresh = await storage.read(AppConstants.refreshTokenKey);
        if (keepSignedIn != 'true' ||
            refresh == null ||
            refresh.trim().isEmpty) {
          return null;
        }
      }
      // This is eligibility to use the established authenticated Dio pipeline,
      // including its refresh interceptor, never proof of server acceptance.
      return owner;
    } catch (_) {
      return null;
    }
  });

  @override
  Future<String?> currentSessionKey() => storage.withSessionLock(() async {
    if (await _currentOwnerId() == null) return null;
    try {
      return await storage.read(generationKey);
    } catch (_) {
      return null;
    }
  });

  /// Call under the same session lock as credential writes. Disable the gate
  /// before changing identity, and enable it only after the new record is whole.
  @override
  Future<void> enableForSession({
    required int userId,
    required String accessToken,
    required bool isTraveler,
  }) async {
    if (!isTraveler || userId <= 0 || tokenOwnerId(accessToken) != userId) {
      if (!await disableForLogout()) {
        throw StateError('Offline identity could not be invalidated.');
      }
      return;
    }
    await storage.write(enabledKey, 'false');
    await storage.write(ownerKey, '$userId');
    await storage.write(generationKey, const Uuid().v4());
    await storage.write(enabledKey, 'true');
  }

  /// Caller holds the session lock when coordinating sign-out. A missing gate
  /// already denies access; failed writes must never be described as logout.
  @override
  Future<bool> disableForLogout() async {
    try {
      final enabled = await storage.read(enabledKey);
      final owner = await storage.read(ownerKey);
      final generation = await storage.read(generationKey);
      if (enabled == null && owner == null && generation == null) return true;
      try {
        await storage.delete(enabledKey);
      } catch (_) {
        try {
          await storage.write(enabledKey, 'false');
        } catch (_) {
          /* Verify below. */
        }
      }
      for (final key in [ownerKey, generationKey]) {
        try {
          await storage.delete(key);
        } catch (_) {
          /* The gate remains authoritative. */
        }
      }
      return await storage.read(enabledKey) != 'true' ||
          int.tryParse(await storage.read(ownerKey) ?? '') == null ||
          (await storage.read(generationKey) ?? '').isEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  bool tokenHasExpired(String? accessToken) {
    final expiry = _claims(accessToken)?['exp'];
    return expiry is num &&
        expiry <= _now().toUtc().millisecondsSinceEpoch ~/ 1000;
  }

  @override
  int? tokenOwnerId(String? accessToken) {
    final claims = _claims(accessToken);
    final raw =
        claims?['sub'] ??
        claims?['nameid'] ??
        claims?['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier'];
    final id = raw is int
        ? raw
        : raw is String
        ? int.tryParse(raw)
        : null;
    return id != null && id > 0 ? id : null;
  }

  static Map<String, dynamic>? _claims(String? token) {
    try {
      final parts = token?.split('.');
      if (parts == null || parts.length != 3) return null;
      final value = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      return value is Map<String, dynamic> ? value : null;
    } catch (_) {
      return null;
    }
  }
}
