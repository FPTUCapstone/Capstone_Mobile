/// English strings for UC-40 (Tour Operator Customer Bookings).
///
/// CR-09: every user-facing text is resource-backed. The messages that have an SRS catalogue entry use the
/// catalogue wording; message ids themselves are internal and are never rendered.
abstract final class OperatorBookingsStringsEn {
  // Messages (SRS catalogue wording)

  /// MSG126: the booking, tour or role is not accessible to this operator.
  static const String accessDenied =
      'Bạn không có quyền truy cập chức năng này.';

  /// MSG127: generic network or server failure.
  static const String systemError =
      'TripMate tạm thời không thể xử lý yêu cầu của bạn. '
      'Vui lòng kiểm tra kết nối mạng và thử lại.';

  /// MSG128: the list has no result for the applied filters.
  static const String noRecords =
      'Không tìm thấy đơn đặt tour nào phù hợp với bộ lọc.';

  /// MSG31: the departure range is inverted.
  static const String dateRangeInvalid =
      'Ngày kết thúc phải lớn hơn hoặc bằng ngày bắt đầu.';

  // Common
  static const String retry = 'Thử lại';
  static const String close = 'Đóng';
  static const String notAvailable = '-';

  // List screen (#84)
  static const String listTitle = 'Đơn đặt tour của khách';
  static const String emptyTitle = 'Không tìm thấy đơn đặt tour';
  static const String searchHint = 'Tìm theo mã đơn, tên hoặc email';
  static const String filtersButton = 'Bộ lọc';
  static const String loadMore = 'Tải thêm';
  static const String loadingMore = 'Đang tải...';
  static const String demoBanner =
      'Dữ liệu mẫu: các đơn đặt tour này chỉ mang tính minh họa, không phải dữ liệu thực tế.';
  static const String summaryBookings = 'Đơn đặt tour';
  static const String summaryBookingsHint = 'Theo bộ lọc hiện tại';
  static const String summaryParticipants = 'Hành khách';
  static const String summaryParticipantsHint = 'Đã xác nhận và hoàn thành';
  static const String summaryRevenue = 'Doanh thu xác nhận';
  static const String summaryRevenueHint = 'Đã xác nhận và hoàn thành';
  static const String cardDeparture = 'Khởi hành';
  static const String cardBooker = 'Người đặt';
  static const String cardParticipants = 'Hành khách';
  static const String cardTotal = 'Tổng tiền';
  static const String cardOpenDetails = 'Xem chi tiết';

  // Status chips and badges
  static const String statusAll = 'Tất cả';
  static const String statusPendingPayment = 'Chờ thanh toán';
  static const String statusConfirmed = 'Đã xác nhận';
  static const String statusCancelled = 'Đã hủy';
  static const String statusCompleted = 'Hoàn thành';
  static const String statusExpired = 'Hết hạn';
  static const String statusInterrupted = 'Bị gián đoạn';
  static const String paymentUnpaid = 'Chưa thanh toán';
  static const String paymentPaid = 'Đã thanh toán';
  static const String paymentRefunded = 'Đã hoàn tiền';
  static const String paymentPartiallyRefunded = 'Hoàn tiền một phần';
  static const String checkedIn = 'Đã điểm danh';
  static const String notCheckedIn = 'Chưa điểm danh';

  // Filter sheet
  static const String filterTitle = 'Bộ lọc';
  static const String filterTour = 'Tour';
  static const String filterAllTours = 'Tất cả tour';
  static const String filterToursUnavailable =
      'Hiện không thể tải danh sách tour; đang hiển thị tất cả tour.';
  static const String filterDepartureFrom = 'Khởi hành từ ngày';
  static const String filterDepartureTo = 'Khởi hành đến ngày';
  static const String filterSelectDate = 'Chọn ngày';
  static const String filterClearDate = 'Xóa ngày';
  static const String filterApply = 'Áp dụng';
  static const String filterReset = 'Đặt lại';

  // Detail screen (#85)
  static const String detailTitle = 'Chi tiết đơn đặt tour';
  static const String detailTour = 'Thông tin tour';
  static const String detailDeparture = 'Khởi hành';
  static const String detailMeetingPoint = 'Điểm đón';
  static const String detailCheckIn = 'Điểm danh';
  static const String detailCheckedInAt = 'Thời gian điểm danh';
  static const String detailBookedAt = 'Ngày đặt';
  static const String detailBooker = 'Người đặt';
  static const String detailPhone = 'Số điện thoại';
  static const String detailEmail = 'Email';
  static const String detailManifest = 'Danh sách hành khách';
  static const String detailTicket = 'Vé điện tử';
  static const String detailTicketCode = 'Mã vé';
  static const String detailTicketStatus = 'Trạng thái vé';
  static const String detailPayment = 'Thanh toán (chỉ xem)';
  static const String detailGateway = 'Cổng thanh toán';
  static const String detailReference = 'Mã giao dịch';
  static const String detailPaidAt = 'Thời gian thanh toán';
  static const String detailAmount = 'Số tiền';
  static const String detailPricing = 'Chi tiết giá';
  static const String detailPaymentStatus = 'Trạng thái thanh toán';
  static const String detailPaidAmount = 'Đã thanh toán';
  static const String detailSubtotal = 'Tạm tính';
  static const String detailDiscount = 'Giảm giá';
  static const String detailCoupon = 'Mã ưu đãi';
  static const String detailTotal = 'Tổng cộng';
  static const String detailCancellation = 'Thông tin hủy đơn';
  static const String detailCancelledAt = 'Thời gian hủy';
  static const String detailCancelReason = 'Lý do';

  // Participant types
  static const String participantAdult = 'Người lớn';
  static const String participantChild = 'Trẻ em';
  static const String participantInfant = 'Em bé';

  // Ticket statuses
  static const String ticketValid = 'Hợp lệ';
  static const String ticketUsed = 'Đã sử dụng';
  static const String ticketCancelled = 'Đã hủy';
  static const String ticketExpired = 'Hết hạn';
}
