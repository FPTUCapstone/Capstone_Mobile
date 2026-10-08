import 'dart:convert';

import 'package:trip_mate_mobile/core/constants/app_constants.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';

/// Helper to resolve the authenticated user ID from stored session JWT.
///
/// In TripMate, the backend issues a JWT access token containing the integer
/// user ID in the standard 'sub' and 'nameid' claims. This helper extracts
/// that identity in a fail-closed manner without introducing third-party dependencies.
abstract final class SessionIdentityHelper {
  /// Extracts the integer user ID from a JWT access token payload.
  ///
  /// Checks standard JWT claim 'sub', ASP.NET short claim 'nameid',
  /// and full URI 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier'.
  /// Returns `null` if the token is missing, malformed, or cannot be parsed.
  static int? parseUserIdFromJwt(String? token) {
    if (token == null || token.trim().isEmpty) return null;
    try {
      final parts = token.trim().split('.');
      if (parts.length < 2) return null;

      final normalized = base64Url.normalize(parts[1]);
      final payloadString = utf8.decode(base64Url.decode(normalized));
      final payload = json.decode(payloadString);

      if (payload is! Map<String, dynamic>) return null;

      final rawSub =
          payload['sub'] ??
          payload['nameid'] ??
          payload['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier'];

      if (rawSub == null) return null;
      if (rawSub is int) return rawSub;
      if (rawSub is String) return int.tryParse(rawSub);
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Asynchronously retrieves the authenticated user ID from [SecureStorageService].
  ///
  /// Returns `null` if unauthenticated, storage is unavailable, or token is invalid.
  static Future<int?> getCurrentUserId([SecureStorageService? storage]) async {
    try {
      final s =
          storage ??
          (serviceLocator.isRegistered<SecureStorageService>()
              ? serviceLocator<SecureStorageService>()
              : null);
      if (s == null) return null;
      final token = await s.read(AppConstants.accessTokenKey);
      return parseUserIdFromJwt(token);
    } catch (_) {
      return null;
    }
  }
}
