import 'package:trip_mate_mobile/core/error/failures.dart';

abstract final class OfflineUiText {
  static const title = 'Dữ liệu ngoại tuyến';
  static const accessTitle = 'Truy cập ngoại tuyến';
  static const empty = 'Chưa có lịch trình đã tải';
  static const emptyHint =
      'Mở chi tiết lịch trình và chọn Tải về xem ngoại tuyến trước khi mất mạng.';
  static const download = 'Tải về xem ngoại tuyến';
  static const cancel = 'Hủy tải';
  static const remove = 'Xóa dữ liệu ngoại tuyến';
  static const update = 'Cập nhật';
  static const open = 'Mở lịch trình';
  static const map = 'Xem bản đồ';
  static const ready = 'Sẵn sàng xem ngoại tuyến';
  static const superseded = 'Có phiên bản mới';
  static const locked =
      'Không còn quyền truy cập lịch trình này. Bạn có thể xóa dữ liệu đã tải.';
  static const sizeLimit = 'Giới hạn gói: 150 MB';
  static const estimateUnknown =
      'Dung lượng ước tính sẽ được kiểm tra khi chuẩn bị tải.';
  static const updateHint =
      'Bản cũ vẫn dùng được trong khi tải bản cập nhật. Cần kết nối mạng để cập nhật.';
  static const success =
      'Đã tải gói lịch trình! Lịch trình hiện có thể xem ngoại tuyến không cần mạng.';
  static const starting =
      'Đang tải gói chuyến đi ngoại tuyến (lịch trình, điểm đến, bản đồ)…';
  static const loadError =
      'Không thể đọc dữ liệu ngoại tuyến. Vui lòng thử lại.';
  static const operationError =
      'Không thể hoàn tất thao tác. Vui lòng thử lại.';
  static const missing =
      'Không tìm thấy gói dữ liệu ngoại tuyến cho lịch trình này.';
  static const corruption =
      'Một số gói dữ liệu bị hỏng và không thể mở. Bạn có thể xóa riêng các gói này rồi tải lại.';
  static const gpsDenied =
      'Chưa có quyền vị trí. Bạn vẫn có thể xem lịch trình và bản đồ đã tải.';
  static String safeError(Object error, [String fallback = operationError]) =>
      error is Failure ? error.message : fallback;
  static String bytes(int value) =>
      '${(value / 1000000).toStringAsFixed(1)} MB';
  static String date(DateTime value) {
    final d = value.toUtc().add(const Duration(hours: 7));
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }
}
