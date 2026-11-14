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

const _en = <SearchText, String>{
  SearchText.systemError:
      'TripMate is temporarily unable to process your request. Please check your connection and try again.',
  SearchText.clearChip: 'Clear filters',
  SearchText.resetEmpty: 'Clear filters',
  SearchText.invalidDestination: 'Enter at most 300 characters.',
  SearchText.invalidPrice:
      'Enter a whole number between 0 and 9,999,999,999 VND.',
  SearchText.invalidDuration: 'Enter a positive whole number of days.',
  SearchText.invalidRating: 'Enter a rating from 1 to 5.',
  SearchText.invalidCategory: 'Select an available category.',
  SearchText.soldOut: 'Sold out',
  SearchText.noSchedule: 'No upcoming schedule',
  SearchText.unknown: 'Availability unknown',
  SearchText.available: 'Available',
  SearchText.language: 'Search language',
  SearchText.title: 'Search Tours',
  SearchText.signIn: 'Sign in',
  SearchText.filterAction: 'Filters',
  SearchText.retry: 'Retry search',
  SearchText.loadFailed: 'Tours could not be loaded',
  SearchText.emptyTitle: 'No matching tours',
  SearchText.emptyMessage:
      'No tour packages found matching your destination and dates.',
  SearchText.previousPage: 'Previous page',
  SearchText.nextPage: 'Next page',
  SearchText.invalidDateRange: 'Start date cannot be after end date.',
  SearchText.invalidPriceRange: 'Minimum price cannot exceed maximum price.',
  SearchText.invalidFilter: 'Check this search filter and try again.',
  SearchText.keyword: 'Keyword',
  SearchText.sort: 'Sort by',
  SearchText.relevance: 'Relevance',
  SearchText.priceAsc: 'Price ascending',
  SearchText.priceDesc: 'Price descending',
  SearchText.ratingSort: 'Highest rated',
  SearchText.departure: 'Departure date',
  SearchText.filters: 'Tour search filters',
  SearchText.destination: 'Destination',
  SearchText.start: 'From date',
  SearchText.end: 'To date',
  SearchText.min: 'Minimum price',
  SearchText.max: 'Maximum price',
  SearchText.duration: 'Duration (days)',
  SearchText.rating: 'Minimum rating',
  SearchText.retryCategories: 'Retry loading categories',
  SearchText.category: 'Category',
  SearchText.allCategories: 'All categories',
  SearchText.apply: 'Apply filters',
  SearchText.clear: 'Clear filters',
  SearchText.chooseDate: 'Choose date',
  SearchText.invalidNumber: 'Enter a valid number.',
};
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

String publicSearchClearDate(String label, bool useEnglish) =>
    useEnglish ? 'Clear $label' : 'Xóa $label';

String publicSearchPage(int page, int total, bool useEnglish) =>
    useEnglish ? 'Page $page of $total' : 'Trang $page / $total';

String publicSearchDays(int days, bool useEnglish) =>
    useEnglish ? '$days days' : '$days ngày';

String publicSearchSlots(int? slots, bool useEnglish) => slots == null
    ? publicSearchCopy(SearchText.available, useEnglish)
    : useEnglish
    ? '$slots places left'
    : 'Còn $slots chỗ';

String publicSearchImage(String title, bool useEnglish) =>
    useEnglish ? 'Image of $title' : 'Ảnh $title';

String publicSearchCount(int count, bool useEnglish) =>
    useEnglish ? '$count tours found' : 'Tìm thấy $count tour';

String publicSearchPriceBound(
  String price,
  bool useEnglish, {
  required bool minimum,
}) => minimum
    ? (useEnglish ? 'From $price' : 'Từ $price')
    : (useEnglish ? 'To $price' : 'Đến $price');
