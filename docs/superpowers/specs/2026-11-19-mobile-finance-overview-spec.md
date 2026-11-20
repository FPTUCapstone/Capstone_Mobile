# Mobile — Tổng quan tài chính gọn (đã duyệt)

Người dùng chốt: Mobile chỉ phục vụ xem nhanh, bỏ liên kết mở báo cáo Web.
Spec này thay thế UX báo cáo đầy đủ trong spec UC44 Mobile trước đó.
BE, UC44 financial authority và API lịch sử quyết toán giữ nguyên.

## Giao diện chính

Một màn hình **Tổng quan tài chính** trong tab Tài chính của shell TO:

1. Tên màn hình, nút làm mới.
2. Tháng/năm đang áp dụng, nút tháng trước và tháng sau.
3. Thẻ Thực nhận nổi bật (`summary.netAmount`), mô tả khoản đã quyết toán
   trừ phần TO hoàn trả đã được xác nhận; theo nhóm đơn thanh toán trong kỳ.
4. Hai thẻ Giá trị tour (`grossRevenue`) và Đã hoàn khách (`refundedAmount`).
5. Dòng `totalBookings` đơn · `totalParticipants` khách.
6. Ba quyết toán gần nhất, nút **Xem tất cả** mở lịch sử riêng.

Không có hai tab con, chart, bảng theo tour, chi tiết tính toán, bộ lọc ngày/tour/
granularity, xuất báo cáo, nút rút tiền hoặc liên kết báo cáo Web trên màn hình này.
Layout wrap/một cột khi 320dp/cỡ chữ lớn; cuộn dọc, không kéo ngang số liệu.

## Tháng và dữ liệu tài chính

- Mặc định tháng hiện tại theo lịch Việt Nam, clock có thể inject trong test.
- Chọn tháng gửi ngày đầu/cuối tháng (bao gồm ngày cuối), granularity monthly,
  không tourId, page1. Không tự thay cách ghi nhận kỳ thanh toán của UC44.
- Chỉ lấy summary cho UI; report API hiện vẫn trả chart/tour rows, không dùng các
  dữ liệu đó để tính lại số. Không sửa BE để thêm endpoint summary trong task này.
- Không tải API tour options ở luồng overview vì không còn bộ lọc tour.
- Đổi tháng chỉ tải report; không lọc lịch sử chuyển tiền theo tháng báo cáo.
- Khi tải tháng mới, giữ nhãn/snapshot tháng committed cho đến khi thành công;
  lỗi có thông báo và retry, không ghép nhãn mới với số tiền cũ hoặc thay bằng0.
- Tháng không có đơn trả0 thật vẫn hiển thị đúng; net0 có đơn là dữ liệu hợp lệ.
- Bảo toàn net âm và toàn bộ số liệu BE, không suy ra thực nhận từ gross/refund/
  commission. `totalBookings` dùng đúng summary UC44, khác số đơn tạo trong tháng.

## Quyết toán gần đây và lịch sử

- Preview gọi first page của `/api/v1/operator/payout-settlements`, giữ thứ tự BE
  và hiển thị tối đa3 row. Không tự cộng tổng hoặc dùng filter tháng report.
  Dòng preview rút gọn ngày/loại, đơn, số tiền/trạng thái; xếp dọc khi màn hình
  hẹp/cỡ chữ lớn. Không dùng lại thẻ lịch sử nhiều dòng cho preview thông thường.
- Ghi rõ preview theo các đợt chuyển tiền gần đây, không phụ thuộc tháng đã chọn.
- Xem tất cả → `/operator/finance/settlements`; read-only, có nút quay lại.
  Trang lịch sử dùng Cubit riêng, phân trang10row, không thay snapshot preview.
- Chạm row vẫn mở chi tiết từ đúng DTO row. Kind Advance/Final/Cancellation,
  status Scheduled/Processing/Settled/SettlementFailed/Resolved/unknown như trước.
  Resolved không có nghĩa chuyển thành công. Không tạo BK-code/ngân hàng/timestamp
  không có trong API; null reference là Chưa có mã giao dịch.
- Demo có banner rõ ở cả overview và trang lịch sử; query demo chỉ có hiệu lực
  debug. Guest/Traveler không được vào route Operator theo guard hiện có.

## State và xác minh

- Lần đầu mở Tài chính tải report + preview; trước khi mở không gọi API tài chính.
- Refresh thủ công/foreground/quay lại tab tải lại cả hai, giữ tháng report đã chọn.
  Report lỗi không chặn preview hợp lệ; history lỗi không che số tiền hợp lệ.
- Chặn double click, response cũ và dữ liệu sau dispose/logout. 401/403 không
  giả thành empty. Dùng central DioClient/SessionCoordinator, không raw HTTP trong UI.
- Test: chỉ3preview từ >=4row; đủ3thẻ + counts, không còn UI cũ/Web link;
  chuyển tháng không gọi history/options; retry không trộn tháng/snapshot;
  toàn0/netâm; UI320dp font2; Xem tất cả dùng route/Cubit độc lập, demo release-safe.

Không push/merge hoặc thay DB. Build/cài emulator chỉ khi nằm trong yêu cầu đã
được cho phép trong phiên; test tay phải báo đúng phần đã kiểm tra.
