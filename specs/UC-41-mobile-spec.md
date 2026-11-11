# UC-41 Cancel Tour Booking — Mobile Spec (draft, chờ duyệt)

Nhánh: `feature/linhnv-uc41-cancel-booking-72h` (worktree `Capstone_Mobile-uc41`, base `develop`)
Hợp đồng BE giống hệt FE: `POST /api/v1/bookings/{bookingId}/cancellation`, `GET /api/v1/bookings/{bookingId}/cancellation-preview`. Mobile gọi thẳng BE, không qua BFF.

## 1. Hiện trạng Mobile (develop)

| Hạng mục | Vị trí | Trạng thái |
|---|---|---|
| Traveler hủy booking | — | Chưa có |
| Operator hủy booking | `operator_bookings` | Chưa có; đã có sẵn `canCancel`/`OperatorCancelBlockedReason` trên `OperatorBookingDetail` nhưng không UI nào dùng (comment: "Kept for the UC-41 task") |
| Trang vé (ngang hàng FE ticket page) | `lib/features/e_ticket/presentation/pages/e_ticket_page.dart` | Có, route `/ticket/:ticketId` và `/bookings/:bookingId/ticket` qua `ETicketKey` |
| Idempotency-Key | `book_tour_cubit.dart` dùng `uuid` v4, sinh mới khi payload đổi, giữ nguyên khi retry cùng payload | Mẫu có sẵn, tái dùng |
| Lỗi theo mã BE | `e_ticket` dùng `Failure` riêng theo `Kind` (không dùng `ErrorMapper` chung) vì cần nhiều nhánh UI khác nhau; `booking_refund` dùng `ErrorMapper` chung (ít nhánh hơn) | UC-41 cần nhiều nhánh như `e_ticket`, nên theo cùng mẫu |

## 2. Phạm vi

Chỉ Traveler (giống quyết định đã chốt cho FE — Operator Mobile để sau, vì Mobile chưa có UI operator cancel nào, không phải sửa cái có sẵn như FE).

Trong phạm vi:
- Nút "Hủy booking" trên `ETicketPage`, trong khối `if (ticket.status.showsQr)` — cùng điều kiện vé `notYetActive`/`valid` như FE.
- Bottom sheet/dialog xác nhận: gọi preview trước, hiển thị mức hoàn.
- Khi preview trả `confirmation_required` (mức hoàn 0%): bắt buộc tick xác nhận trước khi gửi `confirmed = true`.
- Idempotency-Key: `uuid` v4, sinh khi mở dialog, giữ nguyên khi bấm lại cùng lần hủy (như `book_tour_cubit`).
- Sau khi hủy thành công: gọi lại `ETicketCubit.load()` để làm mới trạng thái (ẩn nút, hiện MSG139 "đã hủy").

Ngoài phạm vi:
- Operator cancel trên Mobile.
- Refund (UC-42, UC-67).
- Đổi `operator_bookings` (giữ nguyên các field đã có sẵn).

## 3. Kiến trúc (feature mới `booking_cancellation`, theo Clean Architecture 4 lớp của repo)

```
lib/features/booking_cancellation/
  domain/
    entities/
      booking_cancellation_preview.dart   # canCancel, blockingReasonCode, blockingReason, estimatedRefundAmount, refundStatus, ...
      booking_cancellation_failure.dart   # BookingCancellationFailureKind: signIn, forbidden, notFound, invalidState,
                                           #   reasonRequired, confirmationRequired, paymentNotRefundable, windowClosed,
                                           #   idempotencyMismatch, system
    repositories/
      booking_cancellation_repository.dart
    usecases/
      get_booking_cancellation_preview_use_case.dart
      cancel_booking_use_case.dart
  data/
    datasources/
      booking_cancellation_remote_data_source.dart   # Dio trực tiếp, parse thủ công như booking_refund
    repositories/
      booking_cancellation_repository_impl.dart
  presentation/
    cubit/
      booking_cancellation_cubit.dart   # tải preview, giữ idempotencyKey, gửi hủy
      booking_cancellation_state.dart
    widgets/
      booking_cancel_sheet.dart         # bottom sheet: preview, checkbox xác nhận, nút gửi
```

DI: đăng ký trong `service_locator.dart` theo đúng khối đã có cho `e_ticket`/`booking_refund` (`registerLazySingleton`/`registerFactory`).

## 4. Luồng UI

1. Traveler bấm "Hủy booking" trên `ETicketPage` → mở `BookingCancelSheet` (modal bottom sheet).
2. Sheet gọi preview ngay khi mở → hiện loading → hiện mức hoàn hoặc lý do không hủy được.
3. Nếu `blockingReasonCode = confirmation_required`: hiện checkbox bắt buộc, nút gửi bị khóa đến khi tick.
4. Nếu `canCancel = false` vì lý do khác (đã hủy, đã check-in...): hiện lý do, khóa nút gửi hoàn toàn.
5. Gửi thành công: đóng sheet, gọi `ETicketCubit.load()`, hiện snackbar "Đã hủy booking".
6. Gửi lỗi: hiện lỗi trong sheet, giữ sheet mở để thử lại (cùng Idempotency-Key).

## 5. Thông báo tạm

Chuỗi tiếng Anh tạm trong `lib/features/booking_cancellation/resources/booking_cancellation_en.dart`, đồng bộ nội dung với MSG tạm đã dùng ở BE/FE (MSG123, MSG126, MSG127, MSG131, MSG133, MSG170, …). Ghi chú rõ là tạm, chờ Lead/PO gán mã chính thức — giống quyết định đã chốt cho FE.

## 6. Kiểm thử dự kiến (TDD, khi được duyệt)

- Unit: parse response preview và lỗi của data source (như `booking_refund_remote_data_source` test).
- Unit: cubit — tải preview, giữ idempotencyKey khi submit lại, phát state đúng cho từng `BookingCancellationFailureKind`.
- Widget: `BookingCancelSheet` — mức hoàn >0 không cần checkbox; mức 0% khóa nút đến khi tick; disable khi `canCancel=false`.
- Widget: `ETicketPage` — nút ẩn khi `ticket.status` không phải `notYetActive`/`valid`.

## 7. Known limitation (kế thừa từ BE/FE)

Refund Pending của booking đã có settlement chuyển cho Tour Operator vẫn được xử lý ngay (chưa có UC-42). Khi test, chỉ dùng booking chưa có settlement.
