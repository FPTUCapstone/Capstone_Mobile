abstract final class TravelerEmergencyStringsVi {
  static const pageTitle = 'Thông báo khẩn cấp';
  static const retry = 'Thử lại';
  static const stoppedTitle = 'Tour đã dừng vì an toàn';
  static const cancelledTitle = 'Tour đã bị hủy';
  static const unknownTitle = 'Cập nhật về tour';
  static const notFoundTitle = 'Không có thông báo khẩn cấp';
  static const notFoundMessage =
      'Đơn đặt tour này chưa có thông báo khẩn cấp nào trong tài khoản của bạn.';
  static const loadFailed = 'Không thể tải thông báo khẩn cấp.';
  static const committedAt = 'Thời điểm quyết định';
  static const instructions = 'Chỉ dẫn khẩn cấp';
  static const contact = 'Đầu mối liên hệ khẩn cấp';
  static const noContact = 'Chưa có đầu mối liên hệ khẩn cấp.';
  static const call = 'Gọi đơn vị điều hành';
  static const callFailed = 'Không thể gọi. Vui lòng tự bấm số liên hệ ở trên.';
  static const reason = 'Lý do';
  static const booking = 'Đơn đặt tour của bạn';
  static const bookingStatus = 'Trạng thái đơn';
  static const scheduleStatus = 'Trạng thái lịch khởi hành';
  static const tickets = 'Vé';
  static const paymentHandlingNotice =
      'Việc thanh toán và hoàn tiền được xử lý riêng theo chính sách hủy booking áp dụng.';
  static const staleNotice =
      'Thông báo này có thể chưa được cập nhật. Nội dung sẽ tự làm mới khi có mạng trở lại.';
  static const companionReminder =
      'Nếu người đi cùng không có đơn đặt tour này trong ứng dụng, '
      'hãy tự báo thông báo này cho họ.';
  static const acknowledgeExplanation =
      'Xác nhận chỉ ghi nhận bạn đã đọc thông báo này. Việc này không có nghĩa là '
      'bạn đã an toàn và không làm thay đổi quyết định.';
  static const acknowledge = 'Tôi đã đọc thông báo này';
  static const bannerStopped =
      'Một tour bạn đã đặt đã dừng vì an toàn. Chạm để đọc chỉ dẫn.';
  static const bannerUpdate =
      'Một tour bạn đã đặt có cập nhật quan trọng. Chạm để đọc.';

  static String bannerSeveral(int count) =>
      'Bạn có $count thông báo khẩn cấp chưa đọc. Chạm để xem các chuyến đi.';

  static String acknowledgedAt(String time) => 'Đã ghi nhận lúc $time.';

  static String ticketSummary(int total, int cancelled, int used) =>
      'Tổng $total · Đã hủy $cancelled · Đã dùng $used';
}
