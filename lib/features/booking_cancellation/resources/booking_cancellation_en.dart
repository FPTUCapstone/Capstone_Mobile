/// UC-41 copy. Temporary wording pending Lead/PO sign-off on final MSG codes
/// (mirrors the temporary strings already used on Backend/Web for this task).
abstract final class BookingCancellationStrings {
  static const title = 'Hủy đặt tour';
  static const loading = 'Đang tải thông tin hủy đặt tour…';
  static const refundLabel = 'Số tiền hoàn dự kiến';
  static const refundPending = 'Khoản hoàn tiền sẽ được xử lý (Đang chờ)';
  static const noRefund = 'Không hoàn tiền';
  static const reasonLabel = 'Lý do (không bắt buộc)';
  static const confirmLabel =
      'Tôi xác nhận muốn hủy đơn đặt tour này và đồng ý với số tiền hoàn ở trên.';
  static const confirm = 'Xác nhận hủy';
  static const close = 'Đóng';
  static const cancelled = 'Đã hủy đặt tour.';
  static const retry = 'Thử lại';

  static const signIn = 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
  static const notFound = 'Không tìm thấy đơn đặt tour.';
  static const forbidden = 'Bạn không có quyền hủy đơn đặt tour này.';
  static const invalidState = 'Đơn đặt tour này không còn có thể hủy.';
  static const reasonRequired = 'Vui lòng nhập lý do hủy.';
  static const paymentNotRefundable =
      'Đơn đặt tour này không có giao dịch hợp lệ để hoàn tiền.';
  static const windowClosed =
      'Không thể hủy đơn đặt tour quá sát ngày khởi hành.';
  static const idempotencyMismatch =
      'Không thể xử lý yêu cầu hủy này. Vui lòng thử lại.';
  static const system =
      'TripMate tạm thời không thể xử lý yêu cầu của bạn. Vui lòng kiểm tra kết nối và thử lại.';
}
