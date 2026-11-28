import 'package:equatable/equatable.dart';

sealed class Failure extends Equatable implements Exception {
  const Failure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

final class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Vui lòng kiểm tra kết nối mạng.']);
}

final class ServerFailure extends Failure {
  const ServerFailure([
    super.message = 'Dịch vụ hiện đang tạm gián đoạn. Vui lòng thử lại sau.',
  ]);
}

final class RateLimitFailure extends Failure {
  const RateLimitFailure([
    super.message =
        'Bạn thao tác quá nhiều lần. Vui lòng đợi một chút rồi thử lại.',
  ]);
}

final class RoutingProviderFailure extends Failure {
  const RoutingProviderFailure([
    super.message =
        'Dịch vụ tìm đường tạm thời gián đoạn. Vui lòng thử lại sau.',
  ]);
}

final class AuthenticationFailure extends Failure {
  const AuthenticationFailure([
    super.message = 'Vui lòng đăng nhập để tiếp tục.',
  ]);
}

final class InvalidResetCredentialFailure extends Failure {
  const InvalidResetCredentialFailure([
    super.message =
        'Mã đặt lại mật khẩu không hợp lệ hoặc đã hết hạn. Vui lòng yêu cầu mã mới và thử lại.',
  ]);
}

/// UC-07: the submitted current password does not match the stored hash
/// (Backend MSG17).
final class IncorrectCurrentPasswordFailure extends Failure {
  const IncorrectCurrentPasswordFailure([
    super.message = 'Mật khẩu hiện tại không đúng.',
  ]);
}

/// UC-07: the authenticated account has no local password to change
/// (Google-only account; Backend 403 auth.local_password_unavailable).
final class LocalPasswordUnavailableFailure extends Failure {
  const LocalPasswordUnavailableFailure([
    super.message = 'Tài khoản này chưa thiết lập mật khẩu đăng nhập nội bộ.',
  ]);
}

final class PermissionFailure extends Failure {
  const PermissionFailure([
    super.message = 'Bạn không có quyền truy cập chức năng này.',
  ]);
}

final class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'Không tìm thấy nội dung yêu cầu.']);
}

final class ValidationFailure extends Failure {
  const ValidationFailure(
    super.message, {
    this.fieldErrors = const <String, List<String>>{},
  });

  final Map<String, List<String>> fieldErrors;

  @override
  List<Object?> get props => [message, fieldErrors];
}

final class LocationPermissionFailure extends Failure {
  const LocationPermissionFailure([
    super.message =
        'Không thể dùng vị trí. Bạn vẫn có thể khám phá các địa điểm.',
  ]);
}

final class ConflictFailure extends Failure {
  const ConflictFailure([
    super.message = 'Đã xảy ra xung đột dữ liệu. Vui lòng thử lại.',
    this.groupId,
    this.isIdempotencyKeyPayloadMismatch = false,
  ]);

  final int? groupId;
  final bool isIdempotencyKeyPayloadMismatch;

  @override
  List<Object?> get props => [
    message,
    groupId,
    isIdempotencyKeyPayloadMismatch,
  ];
}

final class ConstraintFailure extends Failure {
  const ConstraintFailure([
    super.message =
        'Thời gian, địa điểm hoặc ngân sách đã chọn chưa thể tạo lịch trình phù hợp.',
  ]);
}

/// An itinerary edit was not saved because one stop would not fit
/// (`itinerary.stop_infeasible`). [poiId] names the stop that breaks;
/// [reason] is the backend reason (`ClosedAtArrival`, `ExceedsEndTime`,
/// `ExceedsBudget`, `OutsideRadius`, `Inactive`, `NoOpeningHours`).
final class StopInfeasibleFailure extends Failure {
  const StopInfeasibleFailure({
    this.poiId,
    this.reason,
    this.plannedArrival,
    this.closesAt,
    this.overflowMinutes,
    this.overflowVnd,
  }) : super('Một địa điểm đã chọn không phù hợp với lịch trình.');

  final int? poiId;
  final String? reason;
  final DateTime? plannedArrival;

  /// "HH:mm" local closing time.
  final String? closesAt;
  final int? overflowMinutes;
  final double? overflowVnd;

  @override
  List<Object?> get props => [
    message,
    poiId,
    reason,
    plannedArrival,
    closesAt,
    overflowMinutes,
    overflowVnd,
  ];
}

enum NavigationFailureReason {
  activeSessionExists,
  outsideTripWindow,
  itineraryNotActive,
  noNavigableItems,
  itineraryScheduleIncomplete,
  sessionCompleted,
  sessionInterrupted,
  itemAlreadyReached,
  itemNotNavigable,
  sessionNotFound,
  accessDenied,
  idempotencyKeyPayloadMismatch,
}

final class NavigationFailure extends Failure {
  const NavigationFailure(
    super.message, {
    required this.reason,
    this.activeSessionId,
  });

  final NavigationFailureReason reason;

  /// Set for [NavigationFailureReason.activeSessionExists].
  final int? activeSessionId;

  @override
  List<Object?> get props => [message, reason, activeSessionId];
}

/// UC-15: the re-routing suggestion cannot be used any more (SRS MSG44).
enum ReroutingFailureReason { notFound, expired, closed, infeasible }

final class ReroutingFailure extends Failure {
  const ReroutingFailure(super.message, {required this.reason});

  final ReroutingFailureReason reason;

  @override
  List<Object?> get props => [message, reason];
}

/// UC-70: stable reasons the Backend rejects an emergency tour request.
enum EmergencyTourFailureReason {
  staleImpact,
  terminal,
  completed,
  wrongActionWindow,
  idempotencyMismatch,
  unverifiedSessions,
  wrongPassword,
  reviewClosed,
  staleEvidence,
}

final class EmergencyTourFailure extends Failure {
  const EmergencyTourFailure(super.message, {required this.reason});

  final EmergencyTourFailureReason reason;

  @override
  List<Object?> get props => [message, reason];
}

final class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'Đã có lỗi xảy ra. Vui lòng thử lại.']);
}
