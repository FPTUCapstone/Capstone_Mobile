# UC-41 Cancel Tour Booking — Mobile Implementation Plan

Spec: `specs/UC-41-mobile-spec.md`
Nhánh: `feature/linhnv-uc41-cancel-booking-72h` (worktree `Capstone_Mobile-uc41`)

Quy ước đã xác nhận trong code trước khi lập plan:
- BE trả DTO thô (`Ok(result.Value)`), không bọc `{data: ...}`. Parser phải xử lý được cả hai dạng (giống `booking_refund`'s `envelope?['data'] is Map ... : envelope`), vì không được giả định hình dạng cố định.
- `Failure` lõi là `sealed class` — feature không thể kế thừa, nên **bắt buộc** có `BookingCancellationFailure` riêng (không phải lựa chọn phong cách).
- Không có mocktail/mockito trong repo. Test dùng fake thủ công implement interface (mẫu `FakeETicketRepository` trong `test/features/e_ticket/presentation/e_ticket_cubit_test.dart`).
- `uuid` và `bloc_test` đã có trong `pubspec.yaml`.
- `bookingId` dùng kiểu `int` xuyên suốt (khớp `ETicket.bookingId`, là nơi gọi vào feature này), không theo quy ước `String` của `booking_refund` (quy ước đó tồn tại vì `OperatorBookingDetail.bookingId` là `String`, không liên quan ở đây).
- Số tiền hoàn dùng kiểu `double`, không phải `int` như `booking_refund_progress.dart`. BE tính `decimal.Round(amount, 2, MidpointRounding.AwayFromZero)` ở `DetermineRefundAmount`/`BookingCancellationRefundRules`, nên có thể ra số lẻ 2 chữ số thập phân; dùng `int` sẽ làm tròn sai lệch số tiền thật.
- Mẫu sheet có cubit riêng: `lib/features/trip_history/presentation/widgets/trip_record_detail_sheet.dart` — `static Future<void> show(BuildContext, {...})` gọi `showModalBottomSheet(..., builder: (_) => BlocProvider(create: (_) => serviceLocator<Cubit>(param1: ...)..load(), child: TheSheet(...)))`. Đây là mẫu đúng cho `BookingCancelSheet`, không dựa vào `BlocProvider` kế thừa từ `ETicketPage` phía trên (dễ sai vì bottom sheet có route/context riêng).
- DI cho cubit nhận tham số: `registerFactoryParam<ETicketCubit, ETicketKey, void>((key, _) => ETicketCubit(...))` — áp dụng tương tự: `registerFactoryParam<BookingCancellationCubit, int, void>((bookingId, _) => BookingCancellationCubit(bookingId: bookingId, ...))`.

Mỗi task: viết test trước (đỏ), triển khai (xanh), refactor. Chạy `flutter test` của task đó trước khi sang task kế tiếp.

## Các task

1. **T1 — Domain entities.**
   - `lib/features/booking_cancellation/domain/entities/booking_cancellation_preview.dart`: `BookingCancellationPreview` (Equatable) — `bookingId` (int), `canCancel` (bool), `blockingReasonCode`/`blockingReason` (String?), `estimatedRefundAmount`/`totalAmount` (**double**, không phải int — xem lý do ở trên), `refundStatus`/`bookingStatus`/`paymentStatus`/`tourTitle` (String). BE còn trả `departureAtUtc`, `quantity` — không đưa vào entity trừ khi T5 cần hiển thị, vì ticket page đã hiện các thông tin này rồi.
   - `.../booking_cancellation_failure.dart`: `BookingCancellationFailureKind` (signIn, forbidden, notFound, invalidState, reasonRequired, confirmationRequired, paymentNotRefundable, windowClosed, idempotencyMismatch, system) + `BookingCancellationFailure implements Exception`.
   - Test: không cần test riêng (entity thuần, không logic) — bỏ qua TDD cho bước này, giống `e_ticket.dart`.

2. **T2 — Data source (parse).**
   - `lib/features/booking_cancellation/data/datasources/booking_cancellation_remote_data_source.dart`: `getPreview(int bookingId)`, `cancel(int bookingId, {String? reasonCategory, String? reasonDetail, required bool confirmed, required String idempotencyKey})`.
   - Dio trực tiếp (`client.dio`), path `/api/v1/bookings/$bookingId/cancellation-preview` (GET) và `/api/v1/bookings/$bookingId/cancellation` (POST, header `Idempotency-Key`).
   - Map lỗi theo `BookingCancellationErrorCodes` của BE (đã đối chiếu): `booking.cancellation.unauthorized`/401→signIn, `booking.cancellation.forbidden`→forbidden, `booking.not_found`→notFound, `booking.cancellation.invalid_state`→invalidState, `booking.cancellation.reason_required`→reasonRequired, `booking.cancellation.confirmation_required`→confirmationRequired, `booking.cancellation.payment_not_refundable`→paymentNotRefundable, `booking.cancellation.window_closed`→windowClosed, `booking.cancellation.idempotency_payload_mismatch`→idempotencyMismatch, còn lại→system.
   - Test (`test/features/booking_cancellation/data/datasources/dio_booking_cancellation_remote_data_source_test.dart`, theo mẫu `dio_booking_refund_remote_data_source_test.dart`): parse preview hợp lệ/hỏng (response không bọc `data`, đúng hình dạng thật `Ok(result.Value)` đã xác nhận trong `BookingsController.cs`); mỗi mã lỗi map đúng kind. Giữ nhánh parse phòng hờ dạng bọc `{data: ...}` trong code (khớp `booking_refund`, không tốn thêm gì), nhưng không viết test cho dạng này vì BE không bao giờ trả như vậy ở hai endpoint này.

3. **T3 — Repository + use cases.**
   - `domain/repositories/booking_cancellation_repository.dart`, `data/repositories/booking_cancellation_repository_impl.dart` (chỉ chuyển tiếp, bắt lỗi không phải `BookingCancellationFailure` thì map thành `system`).
   - `domain/usecases/get_booking_cancellation_preview_use_case.dart`, `cancel_booking_use_case.dart`.
   - Test: cùng file với T2 hoặc file riêng nhỏ, xác nhận lỗi lạ được quy về `system` thay vì rơi ra ngoài.

4. **T4 — Cubit.**
   - `presentation/cubit/booking_cancellation_state.dart`: phase (loading/ready/submitting/success/failure), `preview`, `confirmed` (bool), `idempotencyKey`, `failure`.
   - `presentation/cubit/booking_cancellation_cubit.dart`: constructor nhận `bookingId` (giống `ETicketCubit` nhận `key`, tiêm qua `registerFactoryParam`), tự sinh `idempotencyKey` (uuid v4) một lần trong constructor — giữ nguyên suốt vòng đời cubit, kể cả khi `submit` gọi lại. Khác `book_tour_cubit` (không có "đổi payload thì đổi key" vì không có trường nào đổi được trừ `confirmed`, và đổi `confirmed` vẫn là cùng một ý định hủy).
     - `load()`: gọi preview cho `bookingId` đã có từ constructor, không nhận tham số.
     - `toggleConfirmed(bool value)`.
     - `submit({String? reasonCategory, String? reasonDetail})`: chặn gửi khi `blockingReasonCode == confirmation_required && !confirmed`.
   - Test (`test/features/booking_cancellation/presentation/booking_cancellation_cubit_test.dart`, `bloc_test` + fake repository theo mẫu `FakeETicketRepository`):
     - tải preview thành công/thất bại.
     - mức hoàn >0: submit được ngay không cần `confirmed`.
     - mức 0% (`confirmation_required`): submit bị chặn ở tầng cubit nếu chưa `confirmed`; set `confirmed=true` thì submit được.
     - idempotencyKey không đổi giữa các lần gọi `submit`.
     - submit thất bại giữ nguyên `preview` để người dùng thử lại.

5. **T5 — Widget `BookingCancelSheet`.**
   - `presentation/widgets/booking_cancel_sheet.dart`: `StatelessWidget` + `static Future<bool?> show(BuildContext context, {required int bookingId})` gọi `showModalBottomSheet(..., isScrollControlled: true, useSafeArea: true, showDragHandle: true, builder: (_) => BlocProvider(create: (_) => serviceLocator<BookingCancellationCubit>(param1: bookingId)..load(), child: const BookingCancelSheet()))` — đúng mẫu `TripRecordDetailSheet.show`. Trả `true` khi hủy thành công để `ETicketPage` biết gọi `load()` lại.
   - Hiển thị: loading, mức hoàn, lý do chặn (nếu có), checkbox xác nhận (chỉ khi `confirmation_required`), ô nhập lý do (tùy chọn), nút gửi.
   - Test (`test/features/booking_cancellation/presentation/booking_cancel_sheet_test.dart`, `BlocProvider` bọc fake cubit hoặc cubit thật với fake repository — theo mẫu `e_ticket_page_test.dart`):
     - mức >0: không có checkbox, nút gửi bật ngay.
     - mức 0%: nút gửi tắt đến khi tick checkbox.
     - `canCancel=false`: hiện lý do, nút gửi tắt hẳn.
     - gửi thất bại: hiện thông báo lỗi, sheet không tự đóng.
     - gửi thành công: gọi callback đóng sheet.

6. **T6 — Gắn vào `ETicketPage`.**
   - Trong khối `if (ticket.status.showsQr)`, thêm nút "Hủy booking" sau nút refresh, gọi `BookingCancelSheet.show(context, bookingId: ticket.bookingId)`.
   - Theo đúng mẫu `_confirmRefresh` (bắt `cubit` trước `await` để tránh dùng `context` sau một khoảng `async`, tránh lint `use_build_context_synchronously`):
     ```dart
     final cubit = context.read<ETicketCubit>();
     final cancelled = await BookingCancelSheet.show(context, bookingId: ticket.bookingId);
     if (cancelled == true) await cubit.load();
     ```
   - Test: cập nhật `test/features/e_ticket/presentation/e_ticket_page_test.dart` — nút hiện khi `showsQr`, ẩn khi `cancelled`/`used`/`expired`; bấm nút mở sheet.

7. **T7 — Resources + DI.**
   - `resources/booking_cancellation_en.dart`: chuỗi tạm (đồng bộ với BE/FE), ghi chú chờ Lead/PO gán MSG chính thức.
   - Đăng ký trong `service_locator.dart`, chèn cùng khối với `ETicket`/`BookingRefund` (`registerLazySingleton`/`registerFactory`).
   - Test: không cần test riêng cho resources; DI được xác nhận gián tiếp qua T6 nếu test dựng app thật, hoặc bỏ qua nếu T6 test chỉ dựng widget cô lập.

8. **T8 — Xác minh toàn bộ.**
   - `flutter pub get && dart format --set-exit-if-changed . && flutter analyze && flutter test`.
   - Chạy thử trên thiết bị/giả lập với BE nhánh UC-41 (đã chạy ở cổng 5021): hủy một booking Confirmed của Traveler, kiểm tra mức hoàn >0 và mức 0% (phải tick xác nhận).

## Ngoài phạm vi

- Operator cancel trên Mobile (không UI nào tồn tại để sửa).
- Refund (UC-42, UC-67).
- Thay đổi `operator_bookings` (giữ nguyên `canCancel`/`OperatorCancelBlockedReason` đã có sẵn, không dùng trong UC-41 này).

## Cần người duyệt

Duyệt plan này để bắt đầu T1.
