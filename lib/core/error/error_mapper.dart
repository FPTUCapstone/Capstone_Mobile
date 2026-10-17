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
      final code = extractErrorCode(responseData);
      if (code == 'tour_booking.idempotency_key_required') {
        return const ValidationFailure(
          'Something went wrong preparing this request. Please try again.',
        );
      }
      if (code == 'PAYMENT_BOOKING_NOT_ELIGIBLE') {
        return const ValidationFailure(
          'This booking is not eligible for payment.',
        );
      }
      if (code == 'PAYMENT_BOOKING_EXPIRED') {
        return const ValidationFailure(
          'This booking has expired. Please book a new departure.',
        );
      }
      if (code == 'PAYMENT_MOCK_DISABLED') {
        return const ValidationFailure(
          'Mock payment is not enabled in this environment.',
        );
      }
      if (code == 'PAYMENT_GATEWAY_UNAVAILABLE') {
        return const ServerFailure(
          'The payment gateway is temporarily unavailable. Please try again later.',
        );
      }
      if (code == 'PAYMENT_CALLBACK_INVALID') {
        return const ValidationFailure(
          'The payment response is invalid.',
        );
      }
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
      if (errorCode == 'PAYMENT_NOT_FOUND') {
        return const NotFoundFailure('The payment transaction was not found.');
      }
      if (errorCode == 'travel_group.group_not_found') {
        return const NotFoundFailure();
      }
      if (errorCode == 'travel_group.itinerary_not_found') {
        return const NotFoundFailure(
          'The selected itinerary was not found. Please choose another itinerary.',
        );
      }
      if (errorCode == 'coupon.tour_not_found') {
        return const NotFoundFailure(
          'One or more selected tours are no longer available.',
        );
      }
      if (errorCode == 'tour_booking.schedule_not_found') {
        return const NotFoundFailure(
          'This tour departure is no longer available.',
        );
      }
      if (errorCode == 'tour_booking.voucher_not_found') {
        return const NotFoundFailure('The voucher code was not found.');
      }
      return const NotFoundFailure();
    }
    if (statusCode == 401) return const AuthenticationFailure();
    if (statusCode == 403) return const PermissionFailure();
    if (statusCode == 404) return const NotFoundFailure();
    if (statusCode == 409) {
      if (extractErrorCode(responseData) == 'coupon.code_conflict') {
        return const ConflictFailure('This coupon code is already in use.');
      }
      final operatorTourCode = extractErrorCode(responseData);
      if (operatorTourCode == 'operator_tour.edit_locked' ||
          operatorTourCode == 'operator_tour.invalid_state') {
        return const ConflictFailure(
          'This tour package can no longer be changed. Only Draft or Rejected packages are editable.',
        );
      }
      if (operatorTourCode ==
          'operator_tour.idempotency_key_payload_mismatch') {
        return const ConflictFailure(
          'This request conflicts with an earlier save. Please reopen the form and try again.',
        );
      }
      if (operatorTourCode == 'tour_booking.idempotency_key_payload_mismatch') {
        return const ConflictFailure(
          'The previous booking request did not finish. Please try again.',
          null,
          true,
        );
      }
      if (operatorTourCode == 'tour_booking.schedule_not_open') {
        return const ConflictFailure(
          'This tour departure is no longer open for booking.',
        );
      }
      if (operatorTourCode == 'tour_booking.insufficient_capacity') {
        return const ConflictFailure(
          'Not enough slots remain for this departure. Please reduce the number of travelers.',
        );
      }
      if (operatorTourCode == 'tour_booking.voucher_usage_limit_reached') {
        return const ConflictFailure(
          'This voucher has reached its usage limit.',
        );
      }
      if (operatorTourCode == 'tour_booking.too_many_unpaid_bookings') {
        return const ConflictFailure(
          'You have too many pending bookings. Complete payment or cancel one to continue.',
        );
      }
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
      if (errorCode == 'operator_tour.review_prerequisites_missing') {
        return const ConstraintFailure(
          'This tour is not ready for review yet. Add a cover photo, a future departure, a destination and a cancellation policy, then try again.',
        );
      }
      if (errorCode == 'coupon.tour_not_eligible') {
        return const ConstraintFailure(
          'A selected tour is not approved for coupons. Refresh and choose another tour.',
        );
      }
      if (errorCode == 'itinerary.stop_infeasible') {
        return _stopInfeasible(data);
      }
      if (errorCode == 'itinerary.no_alternative') {
        return const ConstraintFailure(
          'No other places fit this trip\'s time, area and budget. Your current itinerary is already the best option.',
        );
      }
      if (errorCode == 'planning.constraints_infeasible' ||
          errorCode == 'itinerary.constraints_infeasible') {
        final message = _extractSafePlanningMessage(data);
        return ConstraintFailure(message ?? const ConstraintFailure().message);
      }
      if (errorCode == 'tour_booking.voucher_not_eligible') {
        return const ConstraintFailure(
          'This voucher does not apply to the selected tour or is not currently active.',
        );
      }
      if (errorCode == 'tour_booking.voucher_minimum_not_met') {
        return const ConstraintFailure(
          'This voucher requires a higher order amount. Add more travelers or remove the voucher.',
        );
      }
      if (errorCode == 'tour_booking.participants_required') {
        return const ConstraintFailure('At least one traveler is required.');
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

  /// Problem-details extensions are serialized at the root; some proxies nest
  /// them under `extensions`, so both are read.
  static StopInfeasibleFailure _stopInfeasible(Object? data) {
    Object? read(String key) {
      if (data is! Map) return null;
      final extensions = data['extensions'];
      return data[key] ?? (extensions is Map ? extensions[key] : null);
    }

    final arrival = read('plannedArrival');
    final reason = read('reason');
    final closesAt = read('closesAt');
    return StopInfeasibleFailure(
      poiId: switch (read('poiId')) {
        final num value => value.toInt(),
        final String value => int.tryParse(value),
        _ => null,
      },
      reason: reason is String ? reason : null,
      plannedArrival: arrival is String
          ? DateTime.tryParse(arrival)?.toUtc()
          : null,
      closesAt: closesAt is String ? closesAt : null,
      overflowMinutes: switch (read('overflowMinutes')) {
        final num value => value.toInt(),
        _ => null,
      },
      overflowVnd: switch (read('overflowVnd')) {
        final num value => value.toDouble(),
        _ => null,
      },
    );
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
