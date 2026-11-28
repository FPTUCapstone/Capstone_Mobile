abstract final class TourRecommendationsStrings {
  static const String appBarTitle = 'Tour gợi ý cho bạn';
  static const String preferencesTooltip = 'Sở thích du lịch';
  static const String bannerTitle = 'Gợi ý cá nhân hóa (Phù hợp > 80%)';
  static const String bannerDescription =
      'Các tour được tuyển chọn tự động dựa trên sở thích du lịch và chủ đề hành trình bạn yêu thích.';
  static const String bannerEditPreferences = 'Chỉnh sửa sở thích du lịch →';
  static const String pendingIntegrationTitle = 'Gợi ý tour sắp ra mắt';
  static const String pendingIntegrationDescription =
      'Hệ thống gợi ý thông minh đang chờ tích hợp máy chủ. Trong lúc chờ đợi, bạn có thể khám phá tất cả tour hoặc cập nhật sở thích du lịch.';
  static const String exploreAllTours = 'Khám phá tất cả tour';
  static const String updateTravelPreferences = 'Cập nhật sở thích du lịch';
  static const String noPreferencesTitle = 'Chưa thiết lập sở thích';
  static const String setupTravelPreferences = 'Thiết lập sở thích du lịch';
  static const String noMatchesTitle = 'Chưa có tour phù hợp (> 80%)';
  static const String adjustPreferences = 'Điều chỉnh sở thích';
  static const String errorTitle = 'Không thể tải gợi ý tour';
  static const String retry = 'Thử lại';
  static const String previousPage = 'Trang trước';
  static const String nextPage = 'Trang sau';

  static String matchingToursCount(int count) => 'Tìm thấy $count tour phù hợp';
  static String pageIndicator(int current, int total) =>
      'Trang $current / $total';
  static String pageRatio(int current, int total) => '$current / $total';
  static String matchPercent(int percent) => '$percent% phù hợp';

  // Demo Simulation Controls (Debug only)
  static const String demoControlsTitle =
      'ĐIỀU KHIỂN MÔ PHỎNG DEMO (Chỉ chế độ Debug)';
  static const String demoChipSuccess = 'Thành công (>80%)';
  static const String demoChipNoPreferences = 'Chưa có sở thích (MSG183)';
  static const String demoChipNoMatches = 'Chưa có kết quả >80% (MSG64)';
  static const String demoChipError = 'Lỗi mạng (MSG127)';
}
