# UC44 Mobile Finance — Implementation Plan

> Phương án giao diện đã được thay thế bởi
> [plan Tổng quan tài chính](2026-11-19-mobile-finance-overview-plan.md).
> Kết quả kiểm thử cuối tài liệu này là lịch sử xác minh của phiên bản trước.

Ngày: 19/11/2026. **Đã duyệt triển khai cùng hai sửa đổi sau review.**
Spec: [UC44 Mobile Finance](../specs/2026-11-19-uc44-mobile-finance-spec.md).
Triển khai code/test theo các bước dưới đây; chưa build/cài APK hoặc push.

## 0. Baseline, phạm vi và contract

Mobile hiện ở `fix/linhnv-fix-ui-ux`, có thay đổi chưa commit của Traveler UI và
bốn chỉ số TO. Không stash/reset/commit những thay đổi đó tự động, không chuyển
nhánh làm mất chúng. Khi triển khai, giữ nhánh hiện tại nếu người dùng tiếp tục
giao việc trên nhánh này; nếu cần branch riêng, tạo từ đúng baseline đã thống nhất
và giữ nguyên mọi file cũ. Không tự đồng bộ/push hoặc giả định nhánh đang sạch.

Trước code: đọc lại AGENTS/CONTRIBUTING/CODEBASE_RULES, pubspec và spec, xác minh
ba endpoint/DTO BE không thay đổi; chạy baseline analyzer và test shell/demo.
Ghi rõ lỗi baseline nếu có; không sửa lỗi ngoài phạm vi để có kết quả xanh giả.

Kiểm tra nguồn:

- UC44 `OperatorRevenueController`, report/tour-options query DTO và aggregator.
- `OperatorPayoutSettlementsController`, history query/list DTO và status/kind constants.
- Đặc biệt `page` vs `pageNumber`, inclusive endDate, Cancellation, batchId,
  nullable reference và sự khác nhau giữa report cohort / run-date history.

Không sửa BE/schema/formula. Nếu deploy thực tế trả contract khác, ghi dependency,
không dùng demo/zero hoặc bịa endpoint để đi tiếp.

## 1. Domain và contract tests trước implementation

Tạo tập trung trong `lib/features/operator_finance/`:

```text
domain/entities/revenue_report.dart
domain/entities/revenue_query.dart
domain/entities/payout_settlement_history.dart
domain/repositories/operator_finance_repository.dart
data/models/operator_finance_json.dart
data/datasources/operator_finance_remote_data_source.dart
data/repositories/operator_finance_repository_impl.dart
```

Repository có ba operations: loadReport(query), loadTourOptions(),
loadSettlementHistory(page,pageSize). Domain độc lập Flutter/Dio/JSON.
Date-only giữ semantics lịch Việt Nam; tiền giữ giá trị BE, không có calculator.
Không tạo use case wrapper rỗng cho các GET đơn giản.

Test trước ở:

- `test/features/operator_finance/data/operator_finance_json_test.dart`.
- `test/features/operator_finance/data/operator_finance_repository_test.dart`.
- `test/features/operator_finance/domain/revenue_query_test.dart`.

Cases: đầy đủ summary/chart/tour, paging, empty chuẩn BE, NetAmount 4.500 và âm,
thiếu/sai field không trở thành zero, optional IDs/reference/date, ba settlement
kind, Resolved và unknown. Query dùng ngày ISO, `page`, không gửi operatorId;
không đòi appliedFilters/startDate trong chart hoặc field JSON mẫu không tồn tại.
Auth/network/server failures chuyển thành failure abstraction hiện có.

Verification:

```powershell
flutter test --no-pub test/features/operator_finance/domain test/features/operator_finance/data
```

Done: test red quan sát trước, mapper/repository green; review contract + code quality.

## 2. Revenue Cubit — bộ lọc, lifecycle và phân trang

Files:

```text
presentation/cubit/operator_revenue_cubit.dart
presentation/cubit/operator_revenue_state.dart
test/features/operator_finance/presentation/operator_revenue_cubit_test.dart
```

State tách draft/applied query, committed snapshot, request identity,
loading/error/refresh/page. Options loading/error độc lập report để report Tất cả
không bị chặn. Clock injection phục vụ preset Việt Nam/test; không biến clock
device thành nguồn quyết định payout. Kỳ dashboard nếu truyền vào là optional
initial query, không buộc gọi dashboard endpoint để UC44 hoạt động.

Test trước: initial load một lần; invalid range không request; apply reset page1;
cancel draft giữ snapshot; filter mới lỗi không đổi nhãn kỳ committed; stale
response bị bỏ; same query/double submit không duplicate; phân trang commit nguyên
response, test cả fixture tĩnh và BE đổi summary/chart giữa hai trang;
page lỗi giữ trang committed/retry đúng trang; refresh page1 giữ
filter, reset scroll đầu mục active; chuyển mục con giữ page/scroll;
return/foreground refresh mục active; dispose/logout không emit dữ liệu cũ.

Verification:

```powershell
flutter test --no-pub test/features/operator_finance/presentation/operator_revenue_cubit_test.dart
```

Done: data/report/query identity nhất quán, raw exception không đến UI, không có math tài chính.

## 3. UC44 UI cho điện thoại

Files:

```text
presentation/widgets/operator_revenue_report_view.dart
presentation/widgets/revenue_filter_sheet.dart
presentation/widgets/revenue_summary_cards.dart
presentation/widgets/revenue_financial_details.dart
presentation/widgets/revenue_period_chart.dart
presentation/widgets/tour_revenue_list.dart
test/features/operator_finance/presentation/operator_revenue_report_view_test.dart
```

Làm lần lượt: filter sheet → hero Thực nhận + 4 cards → expandable details →
chart một series có giá trị theo kỳ accessible → list tour và detail sheet.
Dùng theme/tokens/formatter hiện có; chưa thay pubspec để thêm chart dependency.
Định danh controller/key từ tourId/periodKey, không dùng vị trí gây tráo row.

Test trước: áp dụng/hủy lọc, lỗi tại trường và scroll/focus hợp lý; không render
sample trên live; loading/empty/net0 có đơn khác nhau; sheet đóng bằng Back;
hiển thị đủ số tiền và labels ở narrow/font lớn; chart chọn series chỉ đổi
field hiển thị từ DTO, không gọi lại API hoặc tự tính lại số tiền/bucket;
tour details từ row, phân trang cập nhật totals theo nguyên response mới;
chart có số âm/trục 0, toàn 0 không chia 0, nhiều bucket render lazy không overflow.

Verification:

```powershell
flutter test --no-pub test/features/operator_finance/presentation/operator_revenue_report_view_test.dart
```

Done: 320dp/390dp và textScale 1.0/1.5/2.0 không overflow; số liệu/lỗi/empty dễ đọc.

## 4. Settlement history Cubit và UI read-only

Files:

```text
presentation/cubit/operator_settlement_history_cubit.dart
presentation/cubit/operator_settlement_history_state.dart
presentation/widgets/operator_settlement_history_view.dart
presentation/widgets/settlement_history_card.dart
presentation/widgets/settlement_detail_sheet.dart
test/features/operator_finance/presentation/operator_settlement_history_cubit_test.dart
test/features/operator_finance/presentation/operator_settlement_history_view_test.dart
```

Load 10 rows/page, giữ thứ tự BE; lỗi trang sau không xóa trang hiện tại.
Refresh về page1. Sheet chỉ dùng list row, xử lý null rõ ràng, copy ID/reference;
không add mutations, detail API, bank fields hoặc filters mà endpoint chưa có.

Test trước: query page đúng, paging/retry/stale response, null date không lệch
ngày; Advance/Final/Cancellation; Scheduled/Processing/Settled/SettlementFailed/
Resolved/unknown; không coi Resolved đã trả tiền; không fabricate Awaiting Window,
BK-code, bank/reference; không render nút retry-transfer/rút tiền/xác nhận.

Verification:

```powershell
flutter test --no-pub test/features/operator_finance/presentation/operator_settlement_history_cubit_test.dart test/features/operator_finance/presentation/operator_settlement_history_view_test.dart
```

Done: history độc lập report period/filter và financial totals, không gọi Admin API.

## 5. Shell, DI, demo và tài liệu contract

Files sửa dự kiến:

- `presentation/widgets/operator_finance_view.dart` trong feature mới: hai mục con,
  lazy load, giữ state/scroll, active/foreground refresh, dispose theo phiên.
- `lib/features/tour_operator/presentation/pages/operator_shell_page.dart`:
  nhãn Tài chính, nối view mới ở index Revenue hiện tại; giữ các tab khác.
- `lib/features/tour_operator/presentation/widgets/operator_revenue_view.dart`:
  thay bằng adapter mỏng hoặc bỏ sau khi không còn references. Nếu giữ demo layout
  cũ, tách rõ explicit demo; không để fake payout/export dialog thành action live.
- `lib/core/di/service_locator.dart`: DataSource/Repository/Cubit factories dùng
  DioClient đã có auth/SessionCoordinator, không khởi tạo client riêng trong UI.
- `docs/mobile-api-contract.md`: bổ sung ba GET với fields/query/paging thực tế.
- Tests shell/demo hiện có và
  `test/features/operator_finance/presentation/operator_finance_view_test.dart`.

Test trước: lần đầu vào không tải cả hai mục; chuyển mục không mất filter/scroll;
refresh chỉ active mục; demo không request BE và banner luôn rõ; logout/đổi user
không giữ dữ liệu; dashboard tap index3 vẫn vào Tài chính; Back sheet không thoát
shell. Cập nhật assertions placeholder Revenue cũ thành hành vi live mới, không
xóa test booking/safety alerts hoặc thay bằng test không có assertion hữu ích.

## 6. Xác minh và review hoàn tất

Theo từng task: test red → minimal implementation → test green → review spec
compliance, rồi code quality bằng agent review theo AGENTS. Không giao agent sửa
đồng thời cùng file. Findings Critical phải sửa trước task tiếp; Minor ghi rõ.

Required checks khi triển khai (không chạy trong lượt chỉ viết tài liệu):

```powershell
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
git diff --check
```

Trước full suite có thể chạy targeted:

```powershell
flutter test --no-pub test/features/operator_finance test/features/tour_operator test/app/router/operator_shell_demo_route_test.dart
```

Nếu baseline/full suite có lỗi ngoài scope, ghi chính xác test lỗi và không tự
khẳng định đã pass. Không sửa/sync generated assets/dependencies ngoài nhu cầu.
User đã yêu cầu chưa build APK/cập nhật emulator: giữ constraint này cho tới khi
có yêu cầu mới; mọi runtime manual check bị giới hạn phải báo rõ.

Manual checklist khi người dùng yêu cầu chạy app:

1. TO đã duyệt: kỳ có dữ liệu và kỳ trống, tour lịch sử, filter trước/sau giao năm.
2. So UC44 Web và Mobile cùng operator/date/tour: summary/chart/tour khớp API,
   gồm net 4.500, chưa payout net0 và refund/return đã xác nhận.
3. History so cùng page/pageSize với API, Cancellation và transferReference null.
4. Mất mạng, retry, next page lỗi, filter nhanh, background/resume, logout/login
   tài khoản khác; không trộn kỳ, row hoặc dữ liệu user.
5. 320dp và cỡ chữ lớn; đọc đủ tiền, chạm chart/card, đóng sheet bằng Back.

Kết quả bàn giao ghi files/behavior/tests/known BE discrepancies trong spec,
không khẳng định đã test runtime nếu chưa chạy. Không commit/push/merge tự động.

## 7. Kết quả triển khai và xác minh

Đã triển khai code Mobile trên nhánh hiện tại, giữ nguyên các thay đổi trước đó.
Hai sửa đổi sau review đã có code và regression tests: commit nguyên response
khi chuyển trang; giữ page/scroll khi đổi mục, reset page1/scroll0 khi reentry/refresh.
Chart có test số âm, toàn0 và 1.000 bucket lazy; các phần mở rộng có Material và
PageStorageKey riêng để không xung đột với scroll state trên Flutter hiện tại.

- `flutter pub get --offline`: thành công, không đổi pubspec/lockfile.
- `flutter analyze --no-pub`: không có issue.
- Format check các file feature/integration đã sửa: không có thay đổi cần format.
- Targeted finance + operator shell/dashboard/demo: **64 test pass**.
- `flutter test --no-pub --concurrency=1`: **2.900 pass, 6 skipped, 0 failed**.
- Review spec compliance và code quality: không còn blocker.
- `git diff --check`: sạch tại lúc xác minh.

Giới hạn: chưa build/cài APK, chưa test tay với BE trên emulator, chưa commit/push.
BE, schema và công thức tài chính không bị sửa trong lần triển khai Mobile này.
