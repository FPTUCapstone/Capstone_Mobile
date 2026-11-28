# Plan Mobile — Direct payment / refund / commission

Ngày 25/11/2026. **Đã ghi nhận duyệt nghiệp vụ ngày 25/11/2026; chưa thực thi.** Phụ thuộc spec/API BE và mobile spec cùng tên được duyệt. Paths mới là đề xuất.

| Task | File/phạm vi | Kiểm chứng / Done |
|---|---|---|
| M1. Khóa contract và route | spec cùng tên; inventory `lib/core` router/DI và feature repositories hiện hữu | Khớp DTO/errors/allowedActions/flow/deadline BE; routes Traveler/TO được duyệt; không Admin |
| M2. Domain/data refund | `lib/features/booking_refund/domain/entities/booking_refund_progress.dart`, `domain/repositories/booking_refund_repository.dart`; thêm usecases recipient/response, data DTO/datasource/repository hiện có | Unit parsing/state/error mapping, owner/auth proxy; dates UTC và completionMethod không bị mất |
| M3. Recipient/response UI | `lib/features/booking_refund/presentation/pages/booking_refund_progress_page.dart`, Cubit/state hiện hữu, form widgets cùng feature | Cubit tests validate/mutate/retry/409; widget tests accept/dispute/partial/auto label; form không cần mở lại |
| M3a. Kết quả tranh chấp | Refund DTO/entities/repositories, Traveler/TO detail Cubits và timeline | Test AdminResolved, yêu cầu bổ sung/chuyển khắc phục, reload sau notification; không có quyền/nút Admin resolve trong app |
| M4. TO refund feature | Mới `lib/features/operator_refunds/{domain,data,presentation}/` nếu inventory xác nhận chưa có; reuse upload infrastructure | Tests private upload/report/idempotency/reference/evidence; hiện toast sau persist, không toast khi mở detail; allowedActions từ BE |
| M5. PayOS thật | `lib/features/payment/{domain,data,presentation}/`, booking flow hiện có | Tests callback/resume/pending/expired/reconciliation và đúng beneficiary; không mock production |
| M6. Kết nối kênh | Mới `lib/features/operator_payment_settings/`, entry từ operator profile/finance hiện có | Cubit tests save/verify/error; secret không persist local; không bypass Ready từ app |
| M7. Hoa hồng/tài chính | `lib/features/operator_finance/domain/repositories/operator_finance_repository.dart`, data implementations, presentation pages/cubits | Tests base/credit/paid vs owed và payment purpose; không dùng demo finance cho production; giữ UI gọn |
| M8. Điều hướng/notifications | Central router + DI files thực tế xác định M1; feature notification handling hiện hữu | Router tests auth/role/deep-link/app resume; không mất bottom menu hoặc back stack; refund/payment reload server |
| M9. Legacy/cutover docs | `README.md`, configuration example nếu cần; flow mapping trong repositories | Tests mixed legacy/direct, canceled ticket, offline mutation disabled; không đổi giờ thiết bị/backend provider để test 72h |

Mỗi task logic phải viết behavioral test trước, chạy focused tests rồi hai lượt review spec/code; không dựng tests chỉ kiểm tra vị trí/căn lề. Không build APK ở từng task nếu không cần xác minh Android runtime.

## Nghiệm thu cuối

- API BE và môi trường DB hoạt động, migration đã verify; không dùng cache/demo để chứng minh tích hợp.
- `flutter pub get`, `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test`; `flutter build apk --debug` khi tích hợp Android hoàn chỉnh.
- Emulator: login từng role, 2 TO/kênh, checkout thật và resume, recipient, báo chuyển, nhận đủ/thiếu/chưa nhận, notification, job auto72h, restart/mạng yếu, không truy cập chéo evidence.
- Dùng fake clock trong automated tests cho mốc 72h; real payment có thời gian thực. Thử tiền thật chỉ sau cho phép cụ thể tài khoản/số tiền; lưu bằng chứng có che thông tin và đối chiếu refund test.
- Build/cài emulator chỉ khi được yêu cầu triển khai; không tạo APK/push/PR từ yêu cầu viết spec và plan này.

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

### Task bổ sung bắt buộc trước nghiệm thu

- Khóa contract cho Admin complaint decision, Traveler/Admin late review, channel approval và credit final settlement; không gộp vào quyền Staff read-only.
- Test Admin complaint decision tạo refund idempotent, chưa đủ bằng chứng không chốt tiền; late-review trước/đúng/sau hạn 7 ngày và điều chỉnh không trùng.
- Test 72h ban đầu/bổ sung và 7 ngày invoice trên server, cuối tuần/lễ không kéo dài; booking gate vẫn cho xử lý nghĩa vụ cũ.
- Test rounding theo booking, refund nhiều lần, credit vượt nợ và đóng TO; ghi history/adjustment bất biến.
- FE bổ sung screen/actions Admin trên Web trong task screen contract; Mobile chỉ TO/Traveler xem kết quả, bổ sung bằng chứng và gửi late review, không làm Admin Flutter.
