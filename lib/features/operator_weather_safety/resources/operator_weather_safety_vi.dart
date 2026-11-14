import 'package:trip_mate_mobile/features/operator_weather_safety/domain/entities/weather_safety_review.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/presentation/cubit/emergency_decision_state.dart';

abstract final class OperatorWeatherSafetyStringsVi {
  static const safetyAlerts = 'Cảnh báo an toàn';
  static const filterAll = 'Tất cả';
  static const emptyTitle = 'Chưa có cảnh báo an toàn';
  static const emptyMessage =
      'Cảnh báo an toàn thời tiết cho các tour của bạn sẽ hiện ở đây.';
  static const staleList =
      'Danh sách này có thể chưa được cập nhật. Danh sách sẽ tự làm mới khi có mạng trở lại.';
  static const loadFailed = 'Không thể tải cảnh báo an toàn.';
  static const notProvided = 'Chưa có thông tin';
  static const staleReview =
      'Cảnh báo này có thể chưa được cập nhật. Nội dung sẽ tự làm mới khi có mạng trở lại.';
  static const retry = 'Thử lại';

  static String reviewStatus(WeatherSafetyReviewStatus status) =>
      switch (status) {
        WeatherSafetyReviewStatus.pendingAcknowledgement => 'Chờ xác nhận',
        WeatherSafetyReviewStatus.escalated => 'Quá hạn xác nhận',
        WeatherSafetyReviewStatus.acknowledged => 'Đã xem',
        WeatherSafetyReviewStatus.closed => 'Đã đóng',
        WeatherSafetyReviewStatus.unknown => 'Không xác định',
      };

  static String badgeSemantics(int count) =>
      '$safetyAlerts, $count cảnh báo cần xử lý';

  // Review detail
  static const reviewTitle = 'Cảnh báo an toàn';
  static const reviewNotFound = 'Không tìm thấy cảnh báo an toàn';
  static const reviewNotFoundMessage =
      'Cảnh báo này không có trong tài khoản của bạn.';
  static const sectionWeather = 'Sự kiện thời tiết';
  static const sectionDeparture = 'Lịch khởi hành';
  static const sectionResponse = 'Phản hồi';
  static const eventType = 'Sự kiện';
  static const severity = 'Mức độ';
  static const description = 'Mô tả';
  static const authority = 'Cơ quan ban hành';
  static const riskLevel = 'Cấp rủi ro chính thức';
  static const directive = 'Chỉ thị';
  static const affectedArea = 'Khu vực ảnh hưởng';
  static const validFrom = 'Hiệu lực từ';
  static const validTo = 'Hiệu lực đến';
  static const withdrawn = 'Sự kiện thời tiết này đã được rút lại.';
  static const scheduleStart = 'Bắt đầu';
  static const scheduleEnd = 'Kết thúc';
  static const scheduleStatus = 'Trạng thái lịch khởi hành';
  static const noticeSent = 'Đã gửi thông báo';
  static const deadline = 'Xác nhận trước';
  static const acknowledgedAt = 'Đã xác nhận';
  static const escalatedAt = 'Đã chuyển cấp xử lý';
  static const escalationContact = 'Đầu mối xử lý';
  static const instructions = 'Chỉ dẫn khẩn cấp';
  static const acknowledgementNote = 'Ghi chú xác nhận nội bộ';
  static const instructionsOptional =
      'Ghi chú xác nhận nội bộ (không bắt buộc)';
  static const acknowledge = 'Xác nhận đã xem';
  static const acknowledgeExplanation =
      'Xác nhận chỉ ghi nhận bạn đã xem cảnh báo này, không làm thay đổi tour, '
      'đơn đặt tour hay chuyến đi.';
  static const reviewDecision = 'Xem phương án khẩn cấp';
  static const manageEvidence = 'Quản lý bằng chứng khẩn cấp';

  // Decision
  static const decisionTitle = 'Quyết định khẩn cấp';
  static const departureNotFound = 'Không tìm thấy lịch khởi hành';
  static const departureNotFoundMessage =
      'Lịch khởi hành này không có trong tài khoản của bạn.';
  static const cancelAction = 'Hủy trước khởi hành';
  static const stopAction = 'Dừng khẩn cấp';
  static const impactTitle = 'Tác động mới nhất';
  static const paidBookings = 'Đơn đã thanh toán';
  static const unpaidBookings = 'Đơn chưa thanh toán';
  static const passengers = 'Hành khách bị ảnh hưởng';
  static const activeSessions = 'Phiên đi tour đang chạy';
  static const unusedTickets = 'Vé chưa dùng';
  static const cancelRefundNotice =
      'Mỗi booking đã thanh toán sẽ được hoàn 100% số tiền đã trả. '
      'Booking chưa thanh toán không phát sinh hoàn tiền.';
  static const stopRefundNotice =
      'Booking đã thanh toán sẽ được TripMate xem xét hoàn phần dịch vụ '
      'chưa thực hiện.';
  static const impactChanged =
      'Tác động đã thay đổi. Vui lòng xem lại tác động mới nhất trước khi xác nhận.';
  static const checkAgain = 'Kiểm tra lại';

  static String blockMessage(EmergencyBlockReason reason) => switch (reason) {
    EmergencyBlockReason.offline =>
      'Bạn đang ngoại tuyến. Chỉ có thể thực hiện thao tác khẩn cấp khi có mạng.',
    EmergencyBlockReason.unverifiedSessions =>
      'Có phiên đi tour chưa được xác minh nên không thể thực hiện thao tác khẩn cấp.',
    EmergencyBlockReason.unsupportedAction =>
      'Phiên bản ứng dụng này không thực hiện được thao tác cần cho lịch khởi hành.',
    EmergencyBlockReason.terminal =>
      'Lịch khởi hành này đã có quyết định cuối cùng.',
    EmergencyBlockReason.completed =>
      'Lịch khởi hành đã hoàn thành nên không thể hủy hoặc dừng.',
    EmergencyBlockReason.forbidden =>
      'Tài khoản của bạn không thể thực hiện thao tác khẩn cấp trên lịch khởi hành này.',
    EmergencyBlockReason.unavailable =>
      'Không tải được tác động mới nhất nên chưa thể thực hiện thao tác khẩn cấp.',
  };

  // Form
  static const reason = 'Lý do';
  static const reasonDetails = 'Lý do hiển thị cho du khách';
  static const reasonRequired = 'Vui lòng nhập lý do.';
  static const instructionsRequired = 'Vui lòng nhập chỉ dẫn khẩn cấp.';
  static const contact = 'Đầu mối liên hệ khẩn cấp';
  static const contactOptional = 'Đầu mối liên hệ khẩn cấp (không bắt buộc)';
  static const contactRequired = 'Vui lòng nhập đầu mối liên hệ khẩn cấp.';
  static const evidenceTitle = 'Bằng chứng (không bắt buộc)';
  static const evidenceUrl = 'Liên kết bằng chứng';
  static const evidenceUrlHint = 'https://';
  static const evidenceUrlInvalid =
      'Vui lòng nhập liên kết HTTPS, không kèm tên đăng nhập hoặc mật khẩu.';
  static const authorityReference = 'Cơ quan ban hành';
  static const evidenceReference = 'Số văn bản';
  static const addLater = 'Bổ sung bằng chứng sau';
  static const authorityEvidenceRequired =
      'Hãy nhập cơ quan ban hành, số văn bản hoặc chọn bổ sung bằng chứng sau.';
  static const password = 'Mật khẩu hiện tại';
  static const passwordRequired = 'Vui lòng nhập mật khẩu hiện tại.';
  static const reviewAndConfirm = 'Xem lại và xác nhận';

  // Confirmation
  static const keepTour = 'Quay lại';
  static const confirmCancelTitle = 'Hủy lịch khởi hành này?';
  static const confirmStopTitle = 'Dừng tour này ngay?';
  static const confirmCancelSubmit = 'Hủy lịch khởi hành';
  static const confirmStopSubmit = 'Dừng tour';
  static const confirmIrreversible =
      'Đây là quyết định cuối cùng và sẽ được thông báo tới các du khách bị ảnh hưởng.';

  static String confirmImpact(int passengers, int paid, int unpaid) =>
      'Ảnh hưởng $passengers hành khách, gồm $paid đơn đã thanh toán và $unpaid đơn chưa thanh toán.';

  // Outcome
  static const ambiguous =
      'Chưa xác nhận được quyết định của bạn đã lưu hay chưa. Gửi lại sẽ dùng đúng '
      'yêu cầu cũ và không tạo quyết định thứ hai.';
  static const retrySubmit = 'Gửi lại đúng yêu cầu này';
  static const checkStatus = 'Kiểm tra trạng thái';
  static const successCancelled = 'Đã hủy lịch khởi hành';
  static const successStopped = 'Đã dừng tour';

  static String successMessage(int bookings) =>
      '$bookings đơn đặt tour bị ảnh hưởng. Du khách có thể đọc quyết định trong ứng dụng.';

  static String successRefundsSubmitted(int requests) =>
      'Đã tạo $requests yêu cầu hoàn tiền.';
  static const successRefundsUnderReview =
      'Các booking đã thanh toán đã được chuyển cho TripMate xem xét hoàn tiền.';

  // Evidence editor
  static const manageEvidenceTitle = 'Bằng chứng khẩn cấp';
  static const evidenceEmpty = 'Vui lòng nhập liên kết hoặc thông tin văn bản.';
  static const evidenceClears =
      'Giá trị đã lưu hiện bên dưới. Khi lưu, nội dung bạn giữ lại được giữ nguyên và ô bạn xóa trống sẽ bị xóa.';
  static const evidenceSave = 'Lưu bằng chứng';
  static const evidenceWithdraw = 'Rút lại bằng chứng';
  static const evidenceWithdrawConfirm = 'Rút lại';
  static const evidenceWithdrawTitle = 'Rút lại bằng chứng?';
  static const evidenceWithdrawMessage =
      'Liên kết và thông tin văn bản đã lưu sẽ bị xóa khỏi quyết định này.';
  static const evidenceSaved = 'Đã lưu bằng chứng.';
  static const evidenceWithdrawn = 'Đã rút lại bằng chứng.';
}
