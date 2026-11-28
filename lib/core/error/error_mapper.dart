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
          'Có lỗi khi chuẩn bị yêu cầu đặt tour. Vui lòng thử lại.',
        );
      }
      if (code == 'PAYMENT_BOOKING_NOT_ELIGIBLE') {
        return const ValidationFailure(
          'Đơn đặt tour này không đủ điều kiện thanh toán.',
        );
      }
      if (code == 'PAYMENT_BOOKING_EXPIRED') {
        return const ValidationFailure(
          'Đơn đặt tour đã hết hạn thanh toán. Vui lòng đặt chuyến khởi hành mới.',
        );
      }
      if (code == 'PAYMENT_MOCK_DISABLED') {
        return const ValidationFailure(
          'Thanh toán mô phỏng không khả dụng trong môi trường này.',
        );
      }
      if (code == 'PAYMENT_GATEWAY_UNAVAILABLE') {
        return const ServerFailure(
          'Cổng thanh toán hiện đang gián đoạn. Vui lòng thử lại sau.',
        );
      }
      if (code == 'PAYMENT_CALLBACK_INVALID') {
        return const ValidationFailure('Phản hồi thanh toán không hợp lệ.');
      }
      return ValidationFailure(
        _extractValidationMessage(responseData) ??
            _safeTitle(responseData) ??
            'Dữ liệu nhập không hợp lệ.',
        fieldErrors: _fieldErrors(responseData),
      );
    }
    if (statusCode == 404) {
      final errorCode = extractErrorCode(responseData);
      if (errorCode == 'Poi.NotFound') return const NotFoundFailure();
      if (errorCode == 'PAYMENT_NOT_FOUND') {
        return const NotFoundFailure('Không tìm thấy giao dịch thanh toán.');
      }
      if (errorCode == 'travel_group.group_not_found') {
        return const NotFoundFailure();
      }
      if (errorCode == 'travel_group.itinerary_not_found') {
        return const NotFoundFailure(
          'Không tìm thấy lịch trình đã chọn. Vui lòng chọn lịch trình khác.',
        );
      }
      if (errorCode == 'coupon.tour_not_found') {
        return const NotFoundFailure(
          'Một hoặc nhiều tour đã chọn không còn khả dụng.',
        );
      }
      if (errorCode == 'tour_booking.schedule_not_found') {
        return const NotFoundFailure(
          'Chuyến khởi hành này không còn khả dụng.',
        );
      }
      if (errorCode == 'tour_booking.voucher_not_found') {
        return const NotFoundFailure('Không tìm thấy mã ưu đãi này.');
      }
      return const NotFoundFailure();
    }
    if (statusCode == 401) return const AuthenticationFailure();
    if (statusCode == 403) return const PermissionFailure();
    if (statusCode == 404) return const NotFoundFailure();
    if (statusCode == 409) {
      if (extractErrorCode(responseData) == 'coupon.code_conflict') {
        return const ConflictFailure('Mã ưu đãi này đã được sử dụng.');
      }
      final operatorTourCode = extractErrorCode(responseData);
      if (operatorTourCode == 'operator_tour.edit_locked' ||
          operatorTourCode == 'operator_tour.invalid_state') {
        return const ConflictFailure(
          'Gói tour này không thể chỉnh sửa. Chỉ có thể sửa gói ở trạng thái Bản nháp hoặc Bị từ chối.',
        );
      }
      if (operatorTourCode ==
          'operator_tour.idempotency_key_payload_mismatch') {
        return const ConflictFailure(
          'Yêu cầu này xung đột với lần lưu trước đó. Vui lòng mở lại biểu mẫu và thử lại.',
        );
      }
      if (operatorTourCode == 'tour_booking.idempotency_key_payload_mismatch') {
        return const ConflictFailure(
          'Yêu cầu đặt tour trước chưa hoàn tất. Vui lòng thử lại.',
          null,
          true,
        );
      }
      if (operatorTourCode == 'tour_booking.schedule_not_open') {
        return const ConflictFailure(
          'Chuyến khởi hành này đã ngừng nhận đặt chỗ.',
        );
      }
      if (operatorTourCode == 'tour_booking.insufficient_capacity') {
        return const ConflictFailure(
          'Không đủ chỗ trống cho chuyến khởi hành này. Vui lòng giảm số lượng khách.',
        );
      }
      if (operatorTourCode == 'tour_booking.voucher_usage_limit_reached') {
        return const ConflictFailure('Mã ưu đãi này đã hết lượt sử dụng.');
      }
      if (operatorTourCode == 'tour_booking.too_many_unpaid_bookings') {
        return const ConflictFailure(
          'Bạn đang có quá nhiều đơn chờ thanh toán. Vui lòng thanh toán hoặc hủy bớt để tiếp tục.',
        );
      }
      final (message, groupId) = _extractConflictDetails(responseData);
      return ConflictFailure(
        message ?? 'Đã xảy ra xung đột dữ liệu. Vui lòng thử lại.',
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
          'Gói tour chưa đủ điều kiện gửi duyệt. Vui lòng bổ sung ảnh bìa, lịch khởi hành tương lai, điểm đến và chính sách hủy rồi thử lại.',
        );
      }
      if (errorCode == 'coupon.tour_not_eligible') {
        return const ConstraintFailure(
          'Một tour đã chọn chưa đủ điều kiện áp dụng mã ưu đãi. Vui lòng tải lại và chọn tour khác.',
        );
      }
      if (errorCode == 'itinerary.stop_infeasible') {
        return _stopInfeasible(data);
      }
      if (errorCode == 'itinerary.no_alternative') {
        return const ConstraintFailure(
          'Không còn địa điểm nào khác phù hợp với thời gian, khu vực và ngân sách. Lịch trình hiện tại đã là phương án tối ưu nhất.',
        );
      }
      if (errorCode == 'planning.constraints_infeasible' ||
          errorCode == 'itinerary.constraints_infeasible') {
        final message = _extractSafePlanningMessage(data);
        return ConstraintFailure(message ?? const ConstraintFailure().message);
      }
      if (errorCode == 'tour_booking.voucher_not_eligible') {
        return const ConstraintFailure(
          'Mã ưu đãi này không áp dụng cho tour đã chọn hoặc hiện chưa có hiệu lực.',
        );
      }
      if (errorCode == 'tour_booking.voucher_minimum_not_met') {
        return const ConstraintFailure(
          'Đơn hàng chưa đạt giá trị tối thiểu để dùng mã ưu đãi này. Hãy thêm khách hoặc gỡ mã.',
        );
      }
      if (errorCode == 'tour_booking.participants_required') {
        return const ConstraintFailure('Cần ít nhất một du khách.');
      }
      return const ConstraintFailure();
    }
    if (statusCode == 503) {
      final data = error.response?.data;
      final errorCode = data is Map ? extractErrorCode(data) : null;
      // ADR-002 (G2): the CSP timed out with no plan; the request is still valid.
      if (errorCode == 'planning.generation_timeout' ||
          errorCode == 'itinerary.generation_timeout') {
        return const ServerFailure(
          'Không thể tạo lịch trình kịp thời gian quy định. Yêu cầu của bạn '
          'vẫn hợp lệ, vui lòng thử lại sau giây lát.',
        );
      }
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
      return 'Lời mời này không hợp lệ, đã hết hạn hoặc không còn khả dụng. Vui lòng kiểm tra lại và thử lại.';
    }
    if (errorCode == 'travel_group.idempotency_key_payload_mismatch') {
      return 'Một yêu cầu trùng lặp với dữ liệu khác đang được xử lý. Vui lòng thử lại.';
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
      return ('Bạn đã là thành viên của nhóm du lịch này.', groupId);
    }
    if (errorCode == 'travel_group.idempotency_key_payload_mismatch') {
      return (
        'Một yêu cầu trùng lặp với dữ liệu khác đang được xử lý. Vui lòng thử lại.',
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
