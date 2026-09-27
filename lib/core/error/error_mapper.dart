import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/error/exceptions.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';

abstract final class ErrorMapper {
  static const _safeValidationTitles = {
    'One or more validation errors occurred.',
  };

  static Failure toFailure(Object error) {
    if (error is Failure) return error;
    if (error is AuthenticationException) {
      return AuthenticationFailure(error.message);
    }
    if (error is NetworkException) return NetworkFailure(error.message);
    if (error is ServerException) return ServerFailure(error.message);
    if (error is DioException) return _mapDioException(error);
    return const UnknownFailure();
  }

  static Failure _mapDioException(DioException error) {
    final statusCode = error.response?.statusCode;
    final responseData = error.response?.data;
    if (extractErrorCode(responseData) == 'MSG127') {
      return const ServerFailure();
    }
    if (statusCode == 429) return const RateLimitFailure();
    if (statusCode == 400) {
      return ValidationFailure(
        _extractValidationMessage(responseData) ??
            _safeTitle(responseData) ??
            'The input provided is invalid.',
        fieldErrors: _fieldErrors(responseData),
      );
    }
    if (statusCode == 404) {
      final errorCode = extractErrorCode(responseData);
      if (errorCode == 'Poi.NotFound') return const NotFoundFailure();
      if (errorCode == 'travel_group.group_not_found') {
        return const NotFoundFailure();
      }
      if (errorCode == 'travel_group.itinerary_not_found') {
        return const NotFoundFailure(
          'The selected itinerary was not found. Please choose another itinerary.',
        );
      }
    }
    if (statusCode == 401) return const AuthenticationFailure();
    if (statusCode == 403) return const PermissionFailure();
    if (statusCode == 409) {
      final (message, groupId) = _extractConflictDetails(responseData);
      return ConflictFailure(
        message ?? 'Conflict occurred. Please try again.',
        groupId,
        extractErrorCode(responseData) ==
            'travel_group.idempotency_key_payload_mismatch',
      );
    }
    if (statusCode == 422) {
      final data = error.response?.data;
      final errorCode = data is Map ? extractErrorCode(data) : null;
      if (errorCode == 'planning.constraints_infeasible') {
        final message = _extractSafePlanningMessage(data);
        return ConstraintFailure(message ?? const ConstraintFailure().message);
      }
      return const ConstraintFailure();
    }
    if (statusCode != null && statusCode >= 500) return const ServerFailure();

    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError => const NetworkFailure(),
      _ => const UnknownFailure(),
    };
  }

  static String? _extractValidationMessage(Object? data) {
    if (data is! Map) return null;

    final errorCode = extractErrorCode(data);
    if (errorCode == 'travel_group.invitation_unavailable') {
      return 'This invitation is invalid, expired, or no longer available. Please check the invitation and try again.';
    }
    if (errorCode == 'travel_group.idempotency_key_payload_mismatch') {
      return 'A conflicting request with different request data is already in progress. Please try again.';
    }

    final errors = data['errors'];
    if (errors is! Map) return null;
    for (final value in errors.values) {
      if (value is List && value.isNotEmpty && value.first is String) {
        final first = (value.first as String).trim();
        if (first.isNotEmpty) return first;
      }
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  static String? _extractSafePlanningMessage(Object? data) {
    if (data is! Map) return null;
    final dynamic raw = data['detail'] ?? data['title'];
    if (raw is! String) return null;
    final message = raw.trim();
    if (message.isEmpty || message.length > 300) return null;
    if (message.toLowerCase().contains('exception') ||
        message.toLowerCase().contains('sql')) {
      return null;
    }
    return message;
  }

  static (String?, int?) _extractConflictDetails(Object? data) {
    if (data is! Map) return (null, null);

    final errorCode = extractErrorCode(data);
    final groupId = _extractGroupId(data);
    if (errorCode == 'travel_group.already_active_member') {
      return ('You are already a member of this travel group.', groupId);
    }
    if (errorCode == 'travel_group.idempotency_key_payload_mismatch') {
      return (
        'A conflicting request with different request data is already in progress. Please try again.',
        groupId,
      );
    }
    return (null, groupId);
  }

  static String? extractErrorCode(Object? data) {
    if (data is! Map) return null;
    final code =
        data['errorCode'] ??
        data['code'] ??
        (data['extensions'] is Map ? data['extensions']['errorCode'] : null);
    return code is String ? code : null;
  }

  static int? _extractGroupId(Map data) {
    final extensions = data['extensions'];
    final rawGroupId =
        (extensions is Map ? extensions['groupId'] : null) ?? data['groupId'];
    if (rawGroupId is num) return rawGroupId.toInt();
    if (rawGroupId is String) return int.tryParse(rawGroupId);
    return null;
  }

  static String? _safeTitle(Object? data) {
    if (data is! Map) return null;
    final title = data['title'];
    if (title is! String) return null;
    final normalized = title.trim();
    return _safeValidationTitles.contains(normalized) ? normalized : null;
  }

  static Map<String, List<String>> _fieldErrors(Object? data) {
    if (data is! Map) return const {};
    final errors = data['errors'];
    if (errors is! Map) return const {};
    return {
      for (final entry in errors.entries)
        if (entry.key is String)
          entry.key as String: switch (entry.value) {
            final List values => values.whereType<String>().toList(),
            final String value => [value],
            _ => const <String>[],
          },
    };
  }
}
