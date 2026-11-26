/// Vietnamese strings for UC-32 (Trip History) and UC-33 (Trip Review).
///
/// CR-09 compliance: All user-facing text is resource-backed.
/// Numeric BR and MSG identifiers are strictly internal and must not be
/// rendered to end users.
abstract final class TripHistoryStringsEn {
  // Screen Titles
  static const String tripHistoryTitle = 'Lịch sử chuyến đi';
  static const String tripReviewTitle = 'Đánh giá chuyến đi';
  static const String editReviewTitle = 'Chỉnh sửa đánh giá';
  static const String viewReviewTitle = 'Đánh giá chuyến đi';
  static const String actionMyComplaints = 'Khiếu nại';
  static const String tooltipMyComplaints = 'Khiếu nại của tôi';

  // Tabs
  static const String tabUpcoming = 'Sắp tới';
  static const String tabCompleted = 'Đã hoàn thành';
  static const String tabCancelled = 'Đã hủy';

  // Filters
  static const String filterDateRange = 'Ngày';
  static const String filterStartDate = 'Từ ngày';
  static const String filterEndDate = 'Đến ngày';
  static const String filterSelectDates = 'Chọn ngày';
  static const String filterClearDates = 'Xóa ngày';
  static const String filterTripType = 'Loại chuyến đi';
  static const String filterAll = 'Tất cả';
  static const String filterTour = 'Tour';
  static const String filterCommercialService = 'Dịch vụ thương mại';
  static const String filterItinerary = 'Lịch trình';
  static const String filterApply = 'Áp dụng';
  static const String filterReset = 'Đặt lại';

  // List Item Fields & Labels
  static const String labelBookingCode = 'Mã đặt chỗ';
  static const String labelDepartureDate = 'Ngày đi';
  static const String labelParticipants = 'Hành khách';
  static const String labelTotalAmount = 'Tổng thanh toán';
  static const String labelFree = 'Free';
  static const String labelStatus = 'Trạng thái';
  static const String labelType = 'Loại';

  // Participant formatting
  static String formatParticipants(int count) => '$count khách';

  // Status Labels
  static const String statusConfirmed = 'Đã xác nhận';
  static const String statusOngoing = 'Đang diễn ra';
  static const String statusCompleted = 'Đã hoàn thành';
  static const String statusCancelled = 'Đã hủy';
  static const String statusStoppedForSafety = 'Đã dừng vì an toàn';

  // Contextual Actions per Record
  static const String actionViewEticket = 'Xem vé điện tử';
  static const String actionWriteReview = 'Viết đánh giá';
  static const String actionEditReview = 'Chỉnh sửa đánh giá';
  static const String actionViewReview = 'Xem đánh giá';
  static const String actionViewRefundStatus = 'Theo dõi hoàn tiền';
  static const String actionViewEmergencyNotice = 'Thông báo khẩn cấp';
  static const String actionViewDetails = 'Xem chi tiết';
  static const String actionCancel = 'Hủy';
  static const String actionClose = 'Đóng';
  static const String actionSubmitReview = 'Gửi đánh giá';
  static const String actionSaveReview = 'Lưu thay đổi';
  static const String actionAddPhoto = 'Thêm ảnh';
  static const String actionRemovePhoto = 'Xóa';
  static const String actionRetry = 'Thử lại';

  // Action Notices & Tooltips
  static const String noticeEticketDemo =
      'Vé điện tử chỉ khả dụng với đơn đặt thật, không hỗ trợ ở chế độ xem thử.';
  static const String noticeReviewNotCompleted =
      'Chỉ có thể gửi đánh giá cho các chuyến đi đã hoàn thành.';
  static const String noticeReviewAlreadyExists =
      'Đơn đặt này đã được đánh giá trước đó.';
  static const String noticeSelfPlannedNoReview =
      'Lịch trình tự lập không áp dụng tính năng đánh giá.';

  // Refund Status Dialog
  static const String refundDialogTitle = 'Thông tin hoàn tiền';
  static const String refundState = 'Trạng thái hoàn tiền';
  static const String refundedAmount = 'Số tiền hoàn';
  static const String refundChannel = 'Kênh hoàn tiền';
  static const String refundNote = 'Ghi chú';
  static const String refundStateRefunded = 'Đã hoàn tiền';
  static const String refundStateProcessing = 'Đang xử lý';
  static const String refundStateNonRefundable = 'Không hoàn tiền';

  // Pagination
  static const String paginationPrevious = 'Trước';
  static const String paginationNext = 'Tiếp';
  static String formatPagination(int page, int totalPages) =>
      'Trang $page / $totalPages';

  // Empty & Error States (UC-32)
  static const String emptyListMessage =
      'Chưa có chuyến đi nào phù hợp với bộ lọc hiện tại.';
  static const String errorMessageGeneric =
      'TripMate tạm thời chưa thể xử lý yêu cầu. Vui lòng kiểm tra kết nối và thử lại.';
  static const String validationDateRangeInvalid =
      'Ngày kết thúc không được sớm hơn ngày bắt đầu.';
  static const String permissionDenied =
      'Bạn không có quyền truy cập chức năng này.';
  static const String tripInformationUnavailable =
      'Không thể tải thông tin chuyến đi.';

  // Screen #74 Review Form
  static const String summarySectionTitle = 'Thông tin chuyến đi';
  static const String summaryTourOrService = 'Tour / Dịch vụ';
  static const String ratingSectionTitle = 'Mức độ hài lòng';
  static const String ratingPrompt = 'Chọn số sao đánh giá';
  static const String reviewTitleLabel = 'Tiêu đề đánh giá';
  static const String reviewTitleHint = 'Tóm tắt trải nghiệm chuyến đi của bạn';
  static const String reviewContentLabel = 'Chia sẻ trải nghiệm';
  static const String reviewContentHint =
      'Chia sẻ cảm nhận về lịch trình, hướng dẫn viên, dịch vụ...';
  static const String photoSectionTitle = 'Ảnh thực tế (không bắt buộc)';
  static const String photoSectionSubtitle =
      'Đính kèm tối đa 5 ảnh (JPG, PNG, WebP · tối đa 5 MB/ảnh)';
  static const String photoPickMockTitle = 'Chọn ảnh đính kèm:';
  static const String photoValidSample = 'Ảnh phong cảnh (hợp lệ, 2.1 MB)';
  static const String photoOversizedSample =
      'Ảnh toàn cảnh độ phân giải cao (quá dung lượng, 6.4 MB)';
  static const String photoUnsupportedSample =
      'Tài liệu chuyến đi (định dạng không hỗ trợ, 1.5 MB)';

  // Review Validation & Feedback Messages (UC-33)
  static const String validationRatingRequired =
      'Vui lòng chọn số sao từ 1 đến 5.';
  static const String validationFieldRequired = 'Trường này là bắt buộc.';
  static const String validationPhotoInvalidType =
      'Chỉ hỗ trợ ảnh định dạng JPEG, PNG hoặc WebP.';
  static const String validationPhotoExceedsLimit =
      'Ảnh đính kèm phải hợp lệ và không vượt quá 5 MB.';
  static const String validationPhotoMaxCount =
      'Bạn chỉ có thể đính kèm tối đa 5 ảnh.';
  static const String validationContentPolicyViolation =
      'Nội dung đánh giá vi phạm chính sách cộng đồng và không thể đăng.';
  static const String reviewReadOnlyNotice =
      'Đã hết thời hạn 7 ngày chỉnh sửa. Đánh giá này hiện chỉ có thể xem.';
  static const String reviewEditWindowActive =
      'Bạn có thể chỉnh sửa đánh giá trong vòng 7 ngày kể từ lúc gửi.';
  static const String reviewSubmitSuccess = 'Đã gửi đánh giá thành công.';
  static const String reviewUpdateSuccess = 'Đã cập nhật đánh giá thành công.';

  // Production Integration Notice
  static const String productionIntegrationPending =
      'Dịch vụ lịch sử chuyến đi đang được kết nối. Các đơn đặt sẽ hiển thị khi hoàn tất tích hợp.';
  static const String productionReviewMutationDisabled =
      'Tính năng gửi đánh giá đang tạm khóa trong khi chờ kết nối máy chủ.';

  // Accessibility Labels
  static const String a11yStarRating = 'Đánh giá {star} trên 5 sao';
  static const String a11ySelectedRating = 'Đã chọn {rating} sao';
  static const String a11yTripCard =
      'Chuyến đi {name}, {status}, khởi hành ngày {date}';
  static const String a11yFilterTab = 'Mục chuyến đi {tab}';

  // --- TM-78 trip detail (UC-32) ---
  static const String detailLoading = 'Đang tải chi tiết chuyến đi…';
  static const String tourSectionTitle = 'Thông tin tour';
  static const String labelDestination = 'Điểm đến';
  static const String scheduleSectionTitle = 'Lịch trình khởi hành';
  static const String labelStarts = 'Bắt đầu';
  static const String labelEnds = 'Kết thúc';
  static const String labelMeetingPoint = 'Điểm đón';
  static const String participantsSectionTitle = 'Hành khách';
  static String formatAdults(int count) => '$count người lớn';
  static String formatChildren(int count) => '$count trẻ em';
  static String formatInfants(int count) => '$count em bé';
  static const String cancellationSectionTitle = 'Thông tin hủy đơn';
  static const String labelCancelledOn = 'Ngày hủy';
  static const String labelCancelReason = 'Lý do';
  static const String refundSectionTitle = 'Thông tin hoàn tiền';
  static const String labelRefundAmount = 'Số tiền hoàn';
  static const String labelRefundChannel = 'Kênh hoàn tiền';
  static const String channelUnavailable = 'Chưa có thông tin';
  static String refundStatusLabel(String status) => switch (status) {
    'Pending' => 'Đang chờ',
    'Processing' || 'RetryPending' => 'Đang xử lý',
    'ManualReview' => 'Đang xem xét',
    'Processed' => 'Đã hoàn tiền',
    'Failed' => 'Thất bại',
    'Rejected' => 'Từ chối',
    _ => status,
  };
  static const String stopsSectionTitle = 'Các điểm dừng';
  static const String stopVisited = 'Đã ghé';
  static const String stopSkipped = 'Đã bỏ qua';
  static const String stopNotVisited = 'Chưa ghé';
  static String formatReachedAt(String dateTime) => 'Đến lúc $dateTime';
  static String formatSkippedAt(String dateTime) => 'Bỏ qua lúc $dateTime';
  static String formatPlannedWindow(String from, String to) =>
      'Dự kiến $from–$to';
  static String formatVisitedOf(int visited, int total) =>
      'Đã ghé $visited/$total điểm';
  static const String sessionSectionTitle = 'Phiên hành trình';
  static const String labelSessionStarted = 'Bắt đầu';
  static const String labelSessionEnded = 'Kết thúc';
  static const String labelSessionReason = 'Kết quả';
  static String completionReasonLabel(String reason) => switch (reason) {
    'RouteFinished' => 'Hoàn tất lộ trình',
    'TravelerStopped' => 'Bạn đã dừng chuyến đi',
    'Expired' => 'Tự động kết thúc khi hết thời gian',
    _ => reason,
  };
  static const String tripRecordUnavailable =
      'Chuyến đi này không còn tồn tại.';
  static String summaryCompletedTrips(int count) => '$count chuyến đã đi';
  static String summaryVisitedPois(int count) => '$count địa điểm đã ghé';
  static String formatStopCount(int count) => '$count điểm dừng';
}
