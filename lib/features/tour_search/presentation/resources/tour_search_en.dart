abstract final class TourSearchEn {
  static const title = 'Tìm kiếm tour';
  static const signIn = 'Đăng nhập';
  static const filters = 'Bộ lọc tour';
  static const clearFilters = 'Xóa bộ lọc';
  static const clear = 'Xóa';
  static const keyword = 'Bạn đang tìm trải nghiệm gì?';
  static const searchMode = 'Chế độ tìm kiếm';
  static const lexical = 'Từ khóa';
  static const semantic = 'Ngữ nghĩa';
  static const hybrid = 'Kết hợp';
  static const sort = 'Sắp xếp';
  static const relevance = 'Phù hợp nhất';
  static const priceAscending = 'Giá: thấp đến cao';
  static const priceDescending = 'Giá: cao đến thấp';
  static const rating = 'Đánh giá';
  static const departureDate = 'Ngày khởi hành';
  static const destination = 'Điểm đến';
  static const startDate = 'Từ ngày';
  static const endDate = 'Đến ngày';
  static const minimumPrice = 'Giá tối thiểu';
  static const maximumPrice = 'Giá tối đa';
  static const duration = 'Thời lượng (ngày)';
  static const minimumRating = 'Đánh giá tối thiểu (1–5)';
  static const category = 'Danh mục';
  static const allCategories = 'Tất cả danh mục';
  static const applyFilters = 'Áp dụng bộ lọc';
  static const retryCategories = 'Không tải được danh mục. Thử lại';
  static const chooseDate = 'Chọn ngày';
  static const reset = 'Đặt lại';
  static const invalidNumber = 'Vui lòng nhập số hợp lệ.';
  static const retrySearch = 'Thử lại';
  static const previousPage = 'Trang trước';
  static const nextPage = 'Trang sau';
  static const soldOut = 'Hết chỗ';
  static const noSchedule = 'Chưa có lịch khởi hành';
  static const availabilityUnknown = 'Tình trạng chỗ chưa xác định';
  static const available = 'Còn chỗ';
  static String days(int count) => '$count ngày';
  static String placesLeft(int? count) =>
      count == null ? available : 'Còn $count chỗ';
  static String imageOf(String title) => 'Ảnh $title';

  static String pageOf(int page, int totalPages) => 'Trang $page / $totalPages';
}
