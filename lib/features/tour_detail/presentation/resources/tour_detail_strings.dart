abstract final class TourDetailStrings {
  // Navigation & App Bar
  static const String appBarTitle = 'Chi tiết tour';
  static const String backTooltip = 'Quay lại';
  static const String shareTooltip = 'Chia sẻ tour';

  // Pending Integration View
  static const String pendingIntegrationTitle = 'Đang kết nối chi tiết tour';
  static const String pendingIntegrationDescription =
      'Tính năng đồng bộ chi tiết tour đang chờ tích hợp máy chủ. Bạn có thể xem thông tin tóm tắt bên dưới hoặc quay lại danh sách tour.';
  static const String backToTourList = 'Quay lại danh sách tour';
  static const String summaryNotice =
      'Đang hiển thị thông tin tóm tắt sơ bộ từ kết quả tìm kiếm.';

  // Error View
  static const String errorTitle = 'Không thể tải chi tiết tour';
  static const String notFoundTitle = 'Tour không khả dụng';
  static const String retry = 'Thử lại';
  static const String loadingLabel = 'Đang tải chi tiết tour';

  // Overview Section
  static const String destinationsLabel = 'Điểm đến';
  static const String operatorLabel = 'Nhà điều hành';
  static const String contactOperator = 'Liên hệ nhà điều hành';
  static String contactOperatorLine(String phone) => '$contactOperator: $phone';
  static String destinationsLine(String destinations) =>
      '$destinationsLabel: $destinations';
  static String durationDays(int days) => '$days ngày';

  // Departure Schedules Section
  static const String schedulesTitle = 'Lịch khởi hành khả dụng';
  static const String noSchedules = 'Hiện chưa có lịch khởi hành khả dụng.';
  static const String soldOut = 'Hết chỗ';
  static const String capacityUnknown = 'Chưa rõ số chỗ';
  static const String registrationClosed = 'Đã đóng đăng ký';
  static const String free = 'Miễn phí';
  static const String vietnamTimeNote =
      'Thời gian hiển thị theo giờ Việt Nam (UTC+7).';
  static String childPriceLine(String price) => 'Trẻ em: $price';
  static String infantPriceLine(String price) => 'Em bé: $price';
  static String meetingPointLine(String place) => 'Điểm đón: $place';
  static String registrationClosesLine(String when) => 'Hạn đăng ký: $when';
  static String asOfNote(String when) =>
      'Số chỗ cập nhật lúc $when (giờ Việt Nam). Hiển thị chỗ trống chưa giữ chỗ.';
  static const String selected = 'Đã chọn';
  static const String selectDeparture = 'Chọn';
  static String remainingSlots(int slots) => 'Còn $slots chỗ';

  // Itinerary Section
  static const String itineraryTitle = 'Lịch trình chi tiết';
  static String dayNumber(int day) => 'Ngày $day';
  static const String noItinerary = 'Lịch trình chưa được công bố.';
  static const String noStopsForDay =
      'Chưa có điểm dừng nào được công bố cho ngày này.';
  static String stayLine(String duration) => 'Lưu lại: $duration';

  // Services & Payment Terms Section
  static const String servicesTitle = 'Dịch vụ & Tiện ích';
  static const String highlightsTitle = 'Điểm nổi bật của tour';
  static const String travellerRequirementsTitle = 'Cần mang theo & Yêu cầu';
  static const String inclusionsTitle = 'Bao gồm';
  static const String exclusionsTitle = 'Không bao gồm';

  // Deposit Policy
  static String depositPolicyBadge(num percent, int daysBefore) {
    final pct = percent == percent.truncate()
        ? percent.toInt().toString()
        : percent.toString();
    return 'Đặt cọc $pct% · Thanh toán phần còn lại trước $daysBefore ngày';
  }

  static String depositPolicyTitle(num percent) {
    final pct = percent == percent.truncate()
        ? percent.toInt().toString()
        : percent.toString();
    return 'Hỗ trợ đặt cọc $pct%';
  }

  static String depositPolicyDescription(num percent, int daysBefore) {
    final pct = percent == percent.truncate()
        ? percent.toInt().toString()
        : percent.toString();
    final remNum = 100 - percent;
    final rem = remNum == remNum.truncate()
        ? remNum.toInt().toString()
        : remNum.toString();
    return 'Đặt cọc $pct% khi đặt tour và thanh toán $rem% còn lại ít nhất $daysBefore ngày trước khi khởi hành. Đặt trong vòng $daysBefore ngày cần thanh toán 100%.';
  }

  // Cancellation Policy
  static const String cancellationPolicyTitle = 'Chính sách hủy';
  static const String noCancellationPolicy =
      'Chưa có chính sách hủy cho tour này.';

  // Reviews Section
  static const String reviewsTitle = 'Đánh giá của du khách';
  static const String noReviews =
      'Chưa có đánh giá nào được công bố cho tour này.';
  static String ratingOutOf5(double rating) => '$rating / 5.0';
  static String reviewCount(int count) => '($count đánh giá)';
  static const String reviewsAggregateOnly =
      'Đánh giá chi tiết từng du khách hiện chưa được hiển thị.';

  // Bottom Booking Bar
  static const String fromPrice = 'Giá từ';
  static const String bookNow = 'Đặt ngay';

  // Dialogs
  static const String loginRequiredTitle = 'Yêu cầu đăng nhập';
  static const String loginRequiredDescription =
      'Bạn cần đăng nhập với tư cách Du khách để đặt tour này.';
  static const String loginLater = 'Để sau';
  static const String loginAction = 'Đăng nhập';

  static const String bookingWorkflowTitle = 'Quy trình đặt tour';
  static const String bookingWorkflowDescription =
      'Đang chuyển sang bước giữ chỗ và thanh toán.';
  static const String close = 'Đóng';

  // Demo Simulation Controls (Debug only)
  static const String demoControlsTitle =
      'ĐIỀU KHIỂN MÔ PHỎNG DEMO (Chỉ chế độ Debug)';
  static const String demoChipAvailable = 'Còn chỗ';
  static const String demoChipSoldOut = 'Hết chỗ (MSG65)';
  static const String demoChipNoReviews = 'Chưa đánh giá (MSG128)';
  static const String demoChipError = 'Lỗi (MSG127)';
}
