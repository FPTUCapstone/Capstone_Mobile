/// Pure Vietnamese UI strings for the shared In-App Notification Inbox.
abstract final class InAppInboxStringsVi {
  static const title = 'Thông báo';
  static const tabAll = 'Tất cả';
  static const tabUnread = 'Chưa đọc';
  static const loadFailed = 'Không thể tải danh sách thông báo.';
  static const genericError =
      'TripMate tạm thời không thể xử lý yêu cầu của bạn. '
      'Vui lòng kiểm tra kết nối và thử lại.';
  static const retry = 'Thử lại';
  static const emptyUnread = 'Không có thông báo chưa đọc.';
  static const emptyAll = 'Chưa có thông báo nào.';
  static const loadMore = 'Tải thêm';
  static const fallbackItemTitle = 'Thông báo';
  static const openAction = 'Mở';
  static const markAsRead = 'Đánh dấu đã đọc';
  static const readLabel = 'Đã đọc';

  static String tabUnreadWithCount(int count) =>
      count > 0 ? '$tabUnread ($count)' : tabUnread;
}
