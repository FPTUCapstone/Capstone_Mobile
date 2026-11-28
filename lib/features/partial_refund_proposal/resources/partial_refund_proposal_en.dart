/// English strings for UC-75 (screen #97 Partial Refund Proposal).
///
/// Messages with an SRS catalogue entry use the catalogue wording; message ids are never rendered.
abstract final class PartialRefundProposalStrings {
  // Messages (SRS catalogue wording)

  /// MSG126: the booking of the complaint belongs to another Traveler.
  static const String accessDenied =
      'Bạn không có quyền truy cập chức năng này.';

  /// MSG127: generic network or server failure.
  static const String systemError =
      'TripMate tạm thời không thể xử lý yêu cầu của bạn. '
      'Vui lòng kiểm tra kết nối và thử lại.';

  /// MSG164: the response is recorded (shown as a toast).
  static const String recorded = 'Phản hồi của bạn đã được ghi nhận.';

  /// MSG165: answered already, or the 3-day response window has closed (BR-153).
  static const String responseClosed =
      'Thời hạn phản hồi đã kết thúc. Yêu cầu này không còn có thể trả lời.';

  static const String notFound =
      'Không tìm thấy đề xuất hoàn tiền một phần này.';

  // Screen
  static const String title = 'Đề xuất hoàn tiền một phần';
  static const String bookingLabel = 'MÃ ĐẶT TOUR';
  static const String proposedAmount = 'Số tiền đề xuất';
  static const String responseDeadline = 'Hạn phản hồi';
  static const String accept = 'Chấp nhận';
  static const String decline = 'Từ chối';
  static const String cancel = 'Hủy';
  static const String retry = 'Thử lại';

  // Confirmation (Normal Flow step 3)
  static const String acceptTitle = 'Chấp nhận hoàn tiền một phần?';
  static String acceptMessage(String amount) =>
      'Bạn đồng ý nhận khoản hoàn tiền $amount cho khiếu nại này. '
      'Khoản tiền sẽ được chi trả sau khi nhà điều hành tour xác nhận.';
  static const String declineTitle = 'Từ chối hoàn tiền một phần?';
  static const String declineMessage =
      'Khiếu nại sẽ được xử lý theo hợp đồng hợp tác.';

  // Status
  static const String statusAwaitingTraveler = 'Chờ phản hồi của bạn';
  static const String descriptionAwaitingTraveler =
      'Nhà điều hành tour đã đề xuất hoàn tiền một phần cho khiếu nại của bạn. '
      'Hãy chấp nhận hoặc từ chối trước hạn phản hồi.';
  static const String statusApproved = 'Đã chấp nhận';
  static const String descriptionApproved =
      'Bạn đã chấp nhận mức tiền đề xuất. Khoản hoàn tiền sẽ được chi trả '
      'sau khi nhà điều hành tour xác nhận.';
  static const String statusDeclined = 'Đã từ chối';
  static const String descriptionDeclined =
      'Đề xuất đã bị từ chối. Khiếu nại sẽ được xử lý theo hợp đồng hợp tác.';
  static const String statusAwaitingOperator = 'Chờ nhà điều hành';
  static const String descriptionAwaitingOperator =
      'Nhà điều hành tour chưa phản hồi khiếu nại này.';
  static const String statusRejected = 'Bị từ chối';
  static const String descriptionRejected =
      'Nhà điều hành tour đã từ chối khiếu nại này. Khiếu nại sẽ được xử lý '
      'theo hợp đồng hợp tác.';
  static const String statusExpired = 'Đã hết hạn';
  static const String descriptionExpired =
      'Nhà điều hành tour không phản hồi đúng hạn. Khiếu nại sẽ được xử lý '
      'theo hợp đồng hợp tác.';
}
