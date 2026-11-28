enum SearchText {
  systemError,
  clearChip,
  resetEmpty,
  invalidDestination,
  invalidPrice,
  invalidDuration,
  invalidRating,
  invalidCategory,
  soldOut,
  noSchedule,
  unknown,
  available,
  language,
  title,
  signIn,
  filterAction,
  retry,
  loadFailed,
  emptyTitle,
  emptyMessage,
  previousPage,
  nextPage,
  invalidDateRange,
  invalidPriceRange,
  invalidFilter,
  keyword,
  sort,
  relevance,
  priceAsc,
  priceDesc,
  ratingSort,
  departure,
  filters,
  destination,
  start,
  end,
  min,
  max,
  duration,
  rating,
  retryCategories,
  category,
  allCategories,
  apply,
  clear,
  chooseDate,
  invalidNumber,
}

const _en = _vi;
const _vi = <SearchText, String>{
  SearchText.systemError:
      'TripMate tạm thời không thể xử lý yêu cầu của bạn. Vui lòng kiểm tra kết nối và thử lại.',
  SearchText.clearChip: 'Xóa lọc',
  SearchText.resetEmpty: 'Đặt lại bộ lọc',
  SearchText.invalidDestination: 'Tối đa 300 ký tự.',
  SearchText.invalidPrice: 'Nhập số nguyên từ 0 đến 9.999.999.999 VNĐ.',
  SearchText.invalidDuration: 'Nhập số ngày nguyên dương.',
  SearchText.invalidRating: 'Nhập điểm đánh giá từ 1 đến 5.',
  SearchText.invalidCategory: 'Chọn danh mục đang khả dụng.',
  SearchText.soldOut: 'Hết chỗ',
  SearchText.noSchedule: 'Chưa có lịch khởi hành',
  SearchText.unknown: 'Tình trạng chỗ chưa xác định',
  SearchText.available: 'Có chỗ',
  SearchText.language: 'Ngôn ngữ tìm kiếm',
  SearchText.title: 'Tìm kiếm Tour',
  SearchText.signIn: 'Đăng nhập',
  SearchText.filterAction: 'Lọc tour',
  SearchText.retry: 'Thử lại',
  SearchText.loadFailed: 'Chưa thể tải danh sách tour',
  SearchText.emptyTitle: 'Không tìm thấy tour phù hợp',
  SearchText.emptyMessage:
      'Không tìm thấy gói tour phù hợp với điểm đến và ngày của bạn.',
  SearchText.previousPage: 'Trang trước',
  SearchText.nextPage: 'Trang tiếp theo',
  SearchText.invalidDateRange: 'Ngày bắt đầu không được sau ngày kết thúc.',
  SearchText.invalidPriceRange: 'Giá tối thiểu không được lớn hơn giá tối đa.',
  SearchText.invalidFilter: 'Vui lòng kiểm tra lại bộ lọc này.',
  SearchText.keyword: 'Từ khóa',
  SearchText.sort: 'Sắp xếp',
  SearchText.relevance: 'Phù hợp nhất',
  SearchText.priceAsc: 'Giá tăng dần',
  SearchText.priceDesc: 'Giá giảm dần',
  SearchText.ratingSort: 'Đánh giá cao',
  SearchText.departure: 'Ngày khởi hành',
  SearchText.filters: 'Bộ lọc tìm kiếm',
  SearchText.destination: 'Điểm đến',
  SearchText.start: 'Từ ngày',
  SearchText.end: 'Đến ngày',
  SearchText.min: 'Giá tối thiểu',
  SearchText.max: 'Giá tối đa',
  SearchText.duration: 'Thời lượng (ngày)',
  SearchText.rating: 'Đánh giá tối thiểu',
  SearchText.retryCategories: 'Thử tải lại danh mục',
  SearchText.category: 'Danh mục',
  SearchText.allCategories: 'Tất cả danh mục',
  SearchText.apply: 'Áp dụng bộ lọc',
  SearchText.clear: 'Xóa bộ lọc',
  SearchText.chooseDate: 'Chọn ngày',
  SearchText.invalidNumber: 'Giá trị số không hợp lệ.',
};

String publicSearchCopy(SearchText key, bool useEnglish) =>
    resolveSearchCopy(key, useEnglish, english: _en, vietnamese: _vi);

String resolveSearchCopy(
  SearchText key,
  bool useEnglish, {
  required Map<SearchText, String> english,
  required Map<SearchText, String> vietnamese,
}) => (useEnglish ? null : vietnamese[key]) ?? english[key] ?? '—';

bool publicSearchUsesEnglish(String? saved, String languageCode) =>
    saved == 'en' || (saved != 'vi' && languageCode.toLowerCase() != 'vi');

String publicSearchClearDate(String label, bool useEnglish) => 'Xóa $label';

String publicSearchPage(int page, int total, bool useEnglish) =>
    'Trang $page / $total';

String publicSearchDays(int days, bool useEnglish) => '$days ngày';

String publicSearchSlots(int? slots, bool useEnglish) => slots == null
    ? publicSearchCopy(SearchText.available, useEnglish)
    : 'Còn $slots chỗ';

String publicSearchImage(String title, bool useEnglish) => 'Ảnh $title';

String publicSearchCount(int count, bool useEnglish) => 'Tìm thấy $count tour';

String publicSearchPriceBound(
  String price,
  bool useEnglish, {
  required bool minimum,
}) => minimum ? 'Từ $price' : 'Đến $price';
