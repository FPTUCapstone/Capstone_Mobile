# Tổng quan tài chính Mobile — plan đã duyệt

Authority: [spec gọn](../specs/2026-11-19-mobile-finance-overview-spec.md).
Giữ dữ liệu BE/UC44 và các thay đổi Traveler/navigation trước đó.

1. **Tests trước:** thay tests của OperatorFinanceView từ hai tab sang overview,
   assert3cards/counts/3recent từ4row, không Web/chart/filter; tháng chỉ report;
   refresh cả hai và UI320dp font2. Test Cubit compact không gọi tour options.
2. **Cubit/DI:** OperatorRevenueCubit thêm tùy chọn không tải tour options lúc
   khởi tạo/apply; DI của overview tắt tùy chọn đó. Query vẫn fullmonth/monthly/
   page1/noTour. Không thay financial calculator hoặc mutate BE.
3. **UI:** thay `operator_finance_view.dart` và thêm `operator_finance_overview.dart`.
   View sở hữu preview Cubit riêng, activate lazy; overview có month controls,
   hero net và hai cards phụ, counts, recent3, independent errors/retry, demo.
   Các widget báo cáo chi tiết cũ không được nối vào luồng live mới.
4. **History riêng:** thêm `operator_settlement_history_page.dart`, AppRoutes
   operatorSettlementHistory và GoRoute trong app_router. Tạo historyCubit riêng
   `ensureLoaded`, giữ existing read-only history view và chi tiết. Query demo
   debug-only. Test direct route/demo và quay lại không đổi preview.
5. **Verification:** format, analyzer, targeted operator_finance/operator shell/
   router tests. Review spec compliance + code quality. Không chạy nhiều Flutter
   process đồng thời. Ghi rõ test/runtime đã chạy, không tự commit/push.

Commands:

```powershell
flutter test --no-pub --concurrency=1 test/features/operator_finance test/features/tour_operator test/app/router/operator_settlement_history_route_test.dart
flutter analyze --no-pub
git diff --check
```

Manual khi có bản cài mới: mở Tài chính, đổi tháng, mở/tắt lịch sử và detail;
kiểm tra recent3 giữ firstpage, thông báo0/lỗi trung thực, số liệu đúng BE.

Kết quả xác minh phần overview: 67 targeted tests passed; `flutter analyze
--no-pub` không có issue; `git diff --check` sạch. Chưa kiểm tra tay bản
overview mới trên emulator; kết quả full-suite trước đó thuộc baseline cũ.

Xác minh trước push ngày 20/11/2026: `flutter pub get` thành công; format toàn
repo 959 file không còn thay đổi; `flutter analyze --no-pub` không có issue;
`flutter test --no-pub --concurrency=2` đạt 2.915 passed, 6 skipped có sẵn.
APK debug đã được build/cài trên emulator ở bước trước; không đưa APK, cache
hoặc file môi trường vào Git. Nhánh đã chứa develop mới nhất lúc kiểm tra.
