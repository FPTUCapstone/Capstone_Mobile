# Mobile spec — Thanh toán trực tiếp TO và refund 72 giờ

Ngày 25/11/2026. Nhánh `fix/linhnv-payout-and-refund`. **Đã duyệt nghiệp vụ ngày 25/11/2026; chưa triển khai.**

## Phạm vi

Nguồn nghiệp vụ/API canonical: BE `specs/direct-operator-payment-refund-spec.md` cùng nhánh. Những policy còn mở ở BE vẫn cần duyệt. Mobile chỉ Traveler và TO, không thêm màn hình Staff/Admin.

Tái dùng các feature `payment`, `booking`, `booking_cancellation`, `booking_refund`, `partial_refund_proposal`, `operator_bookings`, `operator_finance`. `BookingRefundRepository` hiện chỉ có `getProgress`; cần bổ sung use case/mutation thật qua BE, không dùng demo local để coi hoàn thành.

## 1. Thanh toán thật

- Booking hiển thị tên TO/người nhận, số tiền và deadline giữ chỗ 15 phút của server.
- App mở checkout payOS từ link Backend; khi trở về/resume đọc lại trạng thái Backend. Deep link/return URL không xác nhận paid.
- Pending/expired/reconciliation khác thông báo. Lỗi mạng không khẳng định tiền chưa chuyển; có retry trạng thái.
- Không giữ API Key/Checksum Key payOS trong APK, Dart defines hoặc log. Không bật mock ở production.
- Deadline dựa thời gian thực UTC provider/server; không lấy giờ thiết bị hay giờ giả lập nghiệp vụ để tạo link.

## 2. Traveler refund progress

Mở từ booking/trip history/complaint và notification qua route role phù hợp. Mất mạng được xem trạng thái cache có nhãn cũ nếu hiện có cơ chế cache; mọi mutation bắt buộc online, không queue xác nhận tiền để gửi muộn.

Màn hình nhỏ chia thành:

1. Số tiền phải hoàn và badge trạng thái.
2. Hành động hiện tại: nhập recipient / chờ TO / phản hồi giao dịch.
3. Timeline thu gọn và bằng chứng mở theo quyền.

Khi chờ xác nhận:

- Hiển thị TO báo chuyển, amount/reference/thời gian, ảnh hoặc file chứng cứ.
- Hiện ngày giờ hết hạn và số giờ còn lại; thông báo rõ **không phản hồi trong 72 giờ sẽ tự hoàn tất**.
- Có nút **Đã nhận đủ tiền**, **Chưa nhận tiền**, **Nhận thiếu** dễ tiếp cận; phản đối có lý do, thiếu nhập số thực nhận.
- Xác nhận đủ cần dialog; backend trả detail mới, Cubit cập nhật ngay. 409 do hết hạn/xung đột phải refresh.
- Completed phân biệt Traveler xác nhận / tự hoàn sau 72h / Admin kết luận đối soát. Không gắn nhãn ngân hàng xác minh khi tự hoàn.
- Disputed không còn đếm auto-completion. App đóng hoặc offline không làm ngừng deadline trên server.
- Disputed hiển thị yêu cầu bổ sung bằng chứng/kết quả tra soát và kết quả Admin; hai phía được bổ sung theo contract, không sửa/xóa lịch sử. Chưa đủ căn cứ giữ tranh chấp; chuyển lỗi yêu cầu TO khắc phục; đủ căn cứ thì Completed/AdminResolved và thông báo hai bên. Không tạo màn hình ra quyết định Admin trên Flutter.

Recipient form có bank code/account number/account holder theo contract; không tự gọi định dạng đúng là tài khoản đã xác minh. Xác nhận rõ thông tin và quy tắc 72h, hỗ trợ bàn phím/scroll/focus.

## 3. TO

- Kết nối kênh: đề xuất màn hình trong Operator Profile/Finance, form save/verify theo BE; secret chỉ nhập, không đọc lại/lưu máy. Chưa Ready vẫn draft, không mở bán.
- Refund list/detail: nghĩa vụ chuyển toàn bộ amount cho khách, recipient có phân quyền; không hiển thị chia 70/90% với TripMate cho direct.
- Form báo chuyển: reference/time/amount còn thiếu/evidence private; chọn ảnh/file qua cơ chế upload hiện có và policy được duyệt. Upload fail không báo thành công.
- Chỉ sau submit thành công hiện **Đã ghi nhận thông tin chuyển khoản**; đọc detail không hiện success. Hiện deadline Traveler, không reset qua bổ sung evidence.
- Tranh chấp/quá hạn hiển thị hướng dẫn; Staff chỉ theo dõi trên Web, không quyết định hoàn tất. Sau phản đối, không tự mở lại 72h khi TO gửi thêm bằng chứng.
- Tài chính giữ bản tóm tắt dễ đọc: tiền khách trả, đã hoàn, đang chờ hoàn, hoa hồng phải trả/đã trả. Danh sách đối soát tháng và nút thanh toán qua payOS TripMate; không đưa toàn bộ báo cáo quản trị Web lên app.

## 4. Điều hướng, trạng thái, bảo mật

- `go_router` tập trung, đúng `/traveler/*` và `/operator/*`; notification deep link sau đăng nhập kiểm tra quyền và tải dữ liệu server.
- Khi resume: reload refund/payment để không dùng timer stale. `serverNowUtc` giúp hiển thị; Backend quyết định deadline.
- Page → Cubit/BLoC → Use case → repository → data source; không Dio trực tiếp trong widget.
- Ngày hiển thị `dd/MM/yyyy`, giờ Việt Nam; payload ISO/UTC; VND định dạng thống nhất. Không chỉ dùng màu để truyền đạt trạng thái.
- Loading/empty/error/retry, mạng yếu, upload progress, safe area, bàn phím, font lớn, Android back và tab navigation phải hoạt động.
- Private evidence không lưu gallery hay cache public; không log recipient đầy đủ/keys. Không nhúng credential riêng TO trong app.
- Đơn legacy tiếp tục màn hình cũ theo flow; không dispatch action direct vào endpoint legacy.
- Quy tắc thương lượng giữ 2 đề xuất TO/1 counter-offer và lý do theo BE; thống nhất amount chưa đồng nghĩa đã nhận tiền.

## Acceptance

Hai TO đúng beneficiary; paid chỉ theo BE; submit refund cập nhật ngay; phản đối trước hạn chặn auto; hết 72h render Completed đúng method; app restart/offline không kéo dài hạn; ownership/evidence riêng tư; không Admin/Staff Flutter; legacy không hồi quy. Kiểm chứng giao dịch thật riêng với số tiền/tài khoản được cho phép, không tự trả tiền khi viết tài liệu.

## Cập nhật duyệt cuối ngày 25/11/2026

Đã duyệt tám quyết định tại mục 13 spec BE cùng tên. Phần này ưu tiên hơn mọi câu “còn mở/chờ duyệt” cũ nói về tám quyết định đó; không mặc định đã viết hoặc kiểm chứng code.

- Hạn TO chuyển ban đầu và chuyển bổ sung sau quyết định Admin: **72 giờ liên tục**, gồm cuối tuần/lễ. Không còn dùng 3 ngày làm việc. Hạn Traveler phản hồi ban đầu là một cửa sổ 72h riêng.
- Hoa hồng decimal round half up theo booking, rate chụp tại booking, payment xác minh làm base; refund điều chỉnh chênh lệch commission mục tiêu.
- Evidence PDF/JPG/JPEG/PNG, tối đa 5 MB/file, 1–3 file/report, private; retention 24 tháng sau đóng, giữ hồ sơ đang tranh chấp. Admin xử lý hồ sơ có quyền xem; không public evidence.
- Hết lượt thương lượng khiếu nại: `AwaitingAdminReview`, Admin xét và quyết định kết quả/amount theo hợp đồng, chính sách snapshot và bằng chứng. Staff vẫn chỉ theo dõi. Chưa đủ dữ kiện thì yêu cầu bổ sung, không tạo amount giả.
- Sau tranh chấp nhận tiền, không reset 72h bằng báo chuyển bổ sung. Khách nhận đủ hoặc Admin xác minh đủ thì Complete; lưu AdminResolved khi phù hợp.
- Khách được gửi late-review trong 7 ngày sau auto-complete. Admin xem hồ sơ liên kết, không đảo lịch sử/ledger tự động; đây là hạn hỗ trợ nội bộ, không xóa quyền bên ngoài.
- Kênh TO: một kênh active/TO, không chung cho hai TO; Admin đối chiếu/duyệt khi API không đủ xác minh; thay kênh chỉ áp giao dịch mới, giữ kênh cũ cho giao dịch đang có.
- Hoa hồng hạn 7 ngày liên tục từ issuedAt; quá hạn dừng booking mới, vẫn xử lý đơn/refund cũ. Credit bù nợ, dư chuyển kỳ; đóng tài khoản phải đối soát và hoàn credit dư có chứng từ/xác nhận.

