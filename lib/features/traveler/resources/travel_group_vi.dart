/// Pure Vietnamese UI strings for Travel Group Details & UC-20 Remove Group Member.
///
/// SRS message mappings (Report 3):
/// - MSG59: "Are you sure you want to remove {Member_Name} from this group?"
/// - MSG60: "{Member_Name} has been removed from the group."
/// - MSG125: "Your session has expired. Please sign in again to continue."
/// - MSG126: "You do not have permission to access this function."
/// - MSG127: "TripMate is temporarily unable to process your request. Please check your connection and try again."
abstract final class TravelGroupStringsVi {
  // Travel Group Details
  static const groupTitle = 'Nhóm du lịch';
  static const groupHeaderTag = 'NHÓM CHUYẾN ĐI';
  static const roleHost = 'Trưởng nhóm';
  static const roleMember = 'Thành viên';
  static const inviteCodeLabel = 'MÃ MỜI THAM GIA NHÓM';
  static const copy = 'Sao chép';
  static const membersCardTitle = 'Thành viên trong nhóm';
  static const viewAction = 'Xem';
  static const manageMembers = 'Quản lý thành viên';
  static const viewMembers = 'Xem thành viên';
  static const workspaceSection = 'TIỆN ÍCH NHÓM';
  static const groupChatTitle = 'Trò chuyện nhóm';
  static const groupChatSubtitle = 'Nhắn tin, chia tiền & bình chọn';
  static const locationSharingTitle = 'Chia sẻ vị trí';
  static const locationSharingDefaultSubtitle =
      'Cài đặt chia sẻ vị trí với nhóm';
  static const inviteMembersTitle = 'Mời thành viên';
  static const inviteMembersSubtitle = 'Chia sẻ mã mời hoặc mã QR';
  static const leaveGroupButton = 'Rời khỏi nhóm du lịch';
  static const membershipCheckFailed =
      'Không thể xác nhận tư cách thành viên nhóm.';
  static const retry = 'Thử lại';
  static const accessLostNotice = 'Bạn không còn quyền truy cập nhóm này.';
  static const leftAndClosedNotice =
      'Bạn đã rời khỏi nhóm và nhóm đã được đóng.';
  static const leftWithTransferNotice =
      'Bạn đã rời khỏi nhóm. Quyền Trưởng nhóm đã được chuyển giao.';
  static const leftGroupNotice = 'Bạn đã rời khỏi nhóm du lịch.';

  static String fallbackGroupName(int groupId) => 'Nhóm du lịch #$groupId';
  static String copiedInviteCode(String code) => 'Đã sao chép mã mời "$code"';
  static String itineraryLabel(int itineraryId) => 'Lịch trình #$itineraryId';
  static String memberCountShort(int count) => '$count thành viên';
  static String memberCountPeople(int count) => '$count người';
  static String sharingLocationCount(int count) =>
      '$count thành viên đang bật vị trí';

  // UC-20 Group Members
  static const membersTitle = 'Thành viên nhóm';
  static const itineraryAction = 'Lịch trình';
  static const emptyMembers = 'Chưa có thành viên nào trong nhóm.';
  static const hostSection = 'TRƯỞNG NHÓM';
  static const locationEnabled = 'Đang chia sẻ vị trí';
  static const locationDisabled = 'Tắt chia sẻ vị trí';
  static const selfSuffix = ' (Bạn)';
  static const removeAction = 'Xóa';
  static const refresh = 'Làm mới';
  static const removingProgress = 'Đang xóa thành viên khỏi nhóm...';
  static const groupNotFound = 'Không tìm thấy nhóm du lịch này.';
  static const loadMembersFailed =
      'Không thể tải danh sách thành viên. Vui lòng thử lại.';
  static const accessEndedBadge = 'Đã kết thúc';
  static const accessSectionTitle = 'Quyền truy cập nhóm';
  static const backToHome = 'Về trang chủ';
  static const membershipChanged =
      'Trạng thái thành viên đã thay đổi. Vui lòng làm mới danh sách.';
  static const removalValidationIssue =
      'Không thể xóa thành viên này. Vui lòng làm mới và thử lại.';

  static String membersCountInGroup(int count) =>
      '$count thành viên trong nhóm';
  static String otherMembersSection(int count) => 'THÀNH VIÊN ($count)';
  static String joinedOn(String date) => 'Tham gia $date';

  // UC-20 Screen #59 Confirmation Sheet
  static const removeDialogTitle = 'Xóa thành viên khỏi nhóm?';
  static const cancel = 'Hủy';
  static const confirmRemove = 'Xóa thành viên';

  // Locked SRS messages (1-to-1 Vietnamese)
  static String msg59(String memberName) =>
      'Bạn có chắc muốn xóa $memberName khỏi nhóm này không?';
  static String msg60(String memberName) =>
      '$memberName đã được xóa khỏi nhóm.';
  static const msg125 =
      'Phiên đăng nhập của bạn đã hết hạn. Vui lòng đăng nhập lại để tiếp tục.';
  static const msg126 = 'Bạn không có quyền truy cập chức năng này.';
  static const msg127 =
      'TripMate tạm thời không thể xử lý yêu cầu của bạn. '
      'Vui lòng kiểm tra kết nối và thử lại.';
}
