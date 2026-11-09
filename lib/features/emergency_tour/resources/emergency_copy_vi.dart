import 'package:trip_mate_mobile/core/error/failures.dart';

/// The shared failures carry English defaults for the rest of the app.
extension EmergencyFailureCopy on Failure {
  String get viMessage => switch (this) {
    NetworkFailure() => 'Vui lòng kiểm tra kết nối mạng.',
    ServerFailure() => 'Dịch vụ tạm thời không khả dụng. Vui lòng thử lại.',
    RateLimitFailure() => 'Bạn đã thử quá nhiều lần. Vui lòng đợi rồi thử lại.',
    AuthenticationFailure() => 'Vui lòng đăng nhập để tiếp tục.',
    PermissionFailure() => 'Bạn không có quyền thực hiện thao tác này.',
    NotFoundFailure() => 'Không tìm thấy nội dung yêu cầu.',
    UnknownFailure() => 'Đã có lỗi xảy ra. Vui lòng thử lại.',
    _ => message,
  };
}

String departureStatusLabel(String status) => switch (status) {
  'Scheduled' => 'Đã lên lịch',
  'Cancelled' => 'Đã hủy',
  'Completed' => 'Đã hoàn thành',
  'EmergencyStopped' => 'Đã dừng khẩn cấp',
  _ => 'Không xác định',
};

String bookingStatusLabel(String status) => switch (status) {
  'PendingPayment' => 'Chờ thanh toán',
  'Confirmed' => 'Đã xác nhận',
  'Cancelled' => 'Đã hủy',
  'Completed' => 'Đã hoàn thành',
  'Expired' => 'Đã hết hạn',
  'Interrupted' => 'Đã dừng vì an toàn',
  _ => 'Không xác định',
};

String? severityLabel(String? severity) => switch (severity) {
  'Extreme' => 'Cực kỳ nghiêm trọng',
  'Severe' => 'Nghiêm trọng',
  'Moderate' => 'Trung bình',
  'Minor' => 'Nhẹ',
  'Unknown' => 'Không xác định',
  _ => severity,
};
