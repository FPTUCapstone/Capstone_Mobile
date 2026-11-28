import 'package:trip_mate_mobile/features/e_ticket/domain/entities/e_ticket.dart';

/// UC-29 copy. MSG numbers follow Report 3; MSG138–MSG140 come from the UC-29
/// Backend spec §8. Worded for the Traveler who views the ticket.
abstract final class ETicketStrings {
  static const title = 'Vé điện tử';
  static const msg93 =
      'Vé QR mã hóa của bạn đã sẵn sàng. Vui lòng xuất trình mã này tại điểm đón tour.';
  static String msg95(String checkedInAt) =>
      'Vé QR này đã được sử dụng để check-in lúc $checkedInAt.';
  static String msg98(String departureDate) =>
      'Vé này chỉ có hiệu lực vào ngày khởi hành: $departureDate.';
  static const msg126 = 'Bạn không có quyền truy cập chức năng này.';
  static const msg127 =
      'TripMate tạm thời không thể xử lý yêu cầu của bạn. Vui lòng kiểm tra kết nối và thử lại.';
  static const msg138 =
      'Vé điện tử sẽ hiển thị sau khi thanh toán cho đơn đặt tour này được xác nhận.';
  static String msg139(String bookingCode) =>
      'Vé điện tử này đã bị hủy cùng đơn đặt tour $bookingCode và không thể dùng để check-in.';
  static String msg140(String departureDate) =>
      'Vé điện tử này đã hết hạn sau ngày khởi hành $departureDate.';

  static const signIn = 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
  static const notFound = 'Không tìm thấy vé điện tử.';
  static const staleQr =
      'Mã QR trên màn hình có thể không còn hiệu lực. Vui lòng tải lại vé khi có kết nối mạng.';
  static const offline = 'Bạn đang ngoại tuyến — hiện không thể làm mới mã QR.';
  static const meetingPointMissing = 'Chưa cập nhật';
  static String validityNote(String departureDate) =>
      'Chỉ có hiệu lực vào ngày khởi hành $departureDate.';

  static const refresh = 'Làm mới mã QR';
  static const refreshing = 'Đang làm mới…';
  static const refreshConfirm =
      'Mã QR hiện tại sẽ không còn hiệu lực. Bạn có muốn tiếp tục?';
  static const confirmRefresh = 'Làm mới';
  static const cancel = 'Hủy';
  static const retry = 'Thử lại';
  static const back = 'Quay lại';

  static const ticketCode = 'Mã vé';
  static const bookingCode = 'Mã đặt tour';
  static const departure = 'Khởi hành';
  static const meetingPoint = 'Điểm đón';
  static const participants = 'Du khách';
  static const checkedInAt = 'Thời gian check-in';

  static String statusLabel(ETicketStatus status) => switch (status) {
    ETicketStatus.notYetActive => 'Chưa hiệu lực',
    ETicketStatus.valid => 'Còn hiệu lực',
    ETicketStatus.used => 'Đã sử dụng',
    ETicketStatus.cancelled => 'Đã hủy',
    ETicketStatus.expired => 'Hết hạn',
  };

  static String participantSummary(
    int adults,
    int children,
    int infants,
    int total,
  ) {
    final parts = [
      if (adults > 0) '$adults người lớn',
      if (children > 0) '$children trẻ em',
      if (infants > 0) '$infants em bé',
    ];
    return '${parts.join(', ')} ($total du khách)';
  }
}
