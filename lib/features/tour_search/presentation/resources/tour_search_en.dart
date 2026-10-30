abstract final class TourSearchEn {
  static const title = 'Tour search';
  static const signIn = 'Sign in';
  static const filters = 'Tour filters';
  static const clearFilters = 'Clear filters';
  static const clear = 'Clear';
  static const keyword = 'What experience are you looking for?';
  static const searchMode = 'Search mode';
  static const lexical = 'Lexical';
  static const semantic = 'Semantic';
  static const hybrid = 'Hybrid';
  static const sort = 'Sort order';
  static const relevance = 'Relevance';
  static const priceAscending = 'Price: low to high';
  static const priceDescending = 'Price: high to low';
  static const rating = 'Rating';
  static const departureDate = 'Departure date';
  static const destination = 'Destination';
  static const startDate = 'Start date';
  static const endDate = 'End date';
  static const minimumPrice = 'Minimum price';
  static const maximumPrice = 'Maximum price';
  static const duration = 'Duration (days)';
  static const minimumRating = 'Minimum rating (1–5)';
  static const category = 'Category';
  static const allCategories = 'All categories';
  static const applyFilters = 'Apply filters';
  static const retryCategories = 'Categories unavailable. Retry';
  static const chooseDate = 'Choose date';
  static const reset = 'Reset';
  static const invalidNumber = 'Enter a valid number.';
  static const retrySearch = 'Retry search';
  static const previousPage = 'Previous page';
  static const nextPage = 'Next page';
  static const soldOut = 'Sold out';
  static const noSchedule = 'No upcoming schedule';
  static const availabilityUnknown = 'Availability unknown';
  static const available = 'Available';
  static String days(int count) => '$count days';
  static String placesLeft(int? count) =>
      count == null ? available : '$count places left';
  static String imageOf(String title) => 'Image of $title';

  static String pageOf(int page, int totalPages) => 'Page $page of $totalPages';
}
