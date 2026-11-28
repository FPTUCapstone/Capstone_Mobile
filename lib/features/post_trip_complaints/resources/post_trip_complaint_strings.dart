import 'package:trip_mate_mobile/features/post_trip_complaints/domain/entities/post_trip_complaint.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/domain/validation/post_trip_complaint_validation.dart';

abstract final class PostTripComplaintStrings {
  static String categoryLabel(PostTripComplaintReasonCategory category) =>
      switch (category) {
        PostTripComplaintReasonCategory.itineraryNotAsAdvertised =>
          'Lịch trình không đúng như mô tả',
        PostTripComplaintReasonCategory.serviceQuality => 'Chất lượng dịch vụ',
        PostTripComplaintReasonCategory.guideOrStaffConduct =>
          'Thái độ hướng dẫn viên hoặc nhân viên',
        PostTripComplaintReasonCategory.safetyIssue => 'Vấn đề an toàn',
        PostTripComplaintReasonCategory.scheduleChangeOrDelay =>
          'Thay đổi lịch trình hoặc chậm trễ',
        PostTripComplaintReasonCategory.other => 'Khác',
      };
  static String statusLabel(String status) => switch (status) {
    'AwaitingOperatorResponse' => 'Chờ đơn vị điều hành phản hồi',
    'OperatorResponded' => 'Đơn vị điều hành đã phản hồi',
    'UnderReview' || 'UnderAdminReview' => 'Đang được xem xét',
    'Escalated' => 'Đã chuyển xử lý cấp cao',
    'Submitted' => 'Đã gửi',
    'InProgress' => 'Đang xử lý',
    'Resolved' => 'Đã giải quyết',
    'Rejected' => 'Đã từ chối',
    'Closed' => 'Đã đóng',
    _ => status.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (m) => '${m[1]} ${m[2]}',
    ),
  };
  static String validationMessage(PostTripComplaintValidationMessage issue) =>
      switch (issue) {
        PostTripComplaintValidationMessage.requiredDetail => detailRequired,
        PostTripComplaintValidationMessage.detailTooLong =>
          'Nội dung khiếu nại không được vượt quá 2.000 ký tự.',
        PostTripComplaintValidationMessage.unsupportedType =>
          'Chỉ hỗ trợ tệp JPG, PNG, WebP hoặc PDF.',
        PostTripComplaintValidationMessage.fileTooLarge =>
          'Mỗi tệp minh chứng phải có dung lượng lớn hơn 0 và không quá 10 MB.',
        PostTripComplaintValidationMessage.tooManyFiles =>
          'Bạn có thể đính kèm tối đa 5 tệp minh chứng.',
        PostTripComplaintValidationMessage.totalTooLarge =>
          'Tổng dung lượng các tệp minh chứng không được vượt quá 30 MB.',
        PostTripComplaintValidationMessage.missingFileData =>
          'Không thể đọc tệp này. Vui lòng xóa và chọn lại.',
      };
  static const title = 'Gửi khiếu nại sau chuyến đi';
  static const myComplaints = 'Khiếu nại của tôi';
  static const submit = 'Gửi khiếu nại';
  static const amend = 'Bổ sung minh chứng';
  static const download = 'Tải minh chứng';
  static const retry = 'Thử lại';
  static const windowClosed = 'Đã quá thời hạn gửi khiếu nại.';
  static const existing = 'Đơn đặt tour này đã có khiếu nại.';
  static const systemError =
      'TripMate không thể hoàn tất yêu cầu của bạn. Vui lòng thử lại.';
  static const invalidEvidence =
      'Vui lòng chọn tệp JPG, PNG, WebP hoặc PDF đúng giới hạn cho phép.';
  static const tooManyEvidence =
      'Bạn chỉ có thể đính kèm tối đa 5 tệp minh chứng.';
  static const evidenceTooLarge =
      'Mỗi tệp minh chứng tối đa 10 MB và tổng dung lượng không quá 30 MB.';
  static const evidenceTypeInvalid = 'Chỉ hỗ trợ tệp JPG, PNG, WebP và PDF.';
  static const evidenceDataUnavailable =
      'Không thể đọc tệp đã chọn. Vui lòng chọn lại.';
  static const downloadUnavailable =
      'Không thể mở minh chứng. Vui lòng thử tải lại.';
  static const detailRequired = 'Vui lòng nhập nội dung khiếu nại.';
  static const submitted = 'Khiếu nại của bạn đã được gửi.';
  static const evidenceAdded = 'Đã bổ sung minh chứng thành công.';
}
