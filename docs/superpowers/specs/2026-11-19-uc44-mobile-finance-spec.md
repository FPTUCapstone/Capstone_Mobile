# UC44 — Báo cáo doanh thu và lịch sử quyết toán trên Mobile

> Giao diện báo cáo đầy đủ dưới đây đã được người dùng thay thế bằng
> [Tổng quan tài chính gọn](2026-11-19-mobile-finance-overview-spec.md).
> Tài liệu này chỉ còn làm nguồn contract/đối chiếu UC44; không triển khai lại
> hai tab, biểu đồ hoặc bộ lọc nâng cao trong giao diện live Mobile.

## 1. Trạng thái và phạm vi phê duyệt

Ngày soạn: 19/11/2026. **Đã duyệt triển khai trong cuộc trò chuyện**, bao gồm
hai chỉnh sửa sau review: commit nguyên report response khi chuyển trang, và
phân biệt giữ state khi chuyển mục với reset trang/cuộn khi refresh.
Người dùng đã đồng ý phương án UX: tab Tài chính có Báo cáo doanh thu và Lịch sử
quyết toán, giữ thông tin nghiệp vụ nhưng tổ chức theo lớp xem trên màn hình nhỏ.
Được phép triển khai code và test Mobile. Chưa build/cài APK, chạy lại dịch vụ,
thay đổi DB, commit hoặc push.

Spec UC44 BE cũ ghi Web-first/mobile deferred, scope matrix Web ghi cần Owner
quyết định nền tảng. Yêu cầu trực tiếp trong cuộc trò chuyện này cho phép soạn
phạm vi Mobile companion. Không tự nhận đã cập nhật/phê duyệt lại SRS toàn dự án.
UC44 là báo cáo; lịch sử quyết toán là phần đọc API daily settlement riêng,
không gán nghiệp vụ quyết toán tự động vào UC44 hoặc bản UC46 cũ.

### Nguồn đối chiếu

Đường dẫn dưới đây tính từ workspace `D:/study/Project-Capstone`:

- `Capstone_BE-user-profile-book-tour/specs/UC-44-view-revenue-report-be-spec.md`.
- `Capstone_BE-user-profile-book-tour/src/TripMate.Application/Features/Operator/Revenue/Common/OperatorRevenueAggregator.cs`.
- Các query/DTO trong `.../Features/Operator/Revenue/GetReport` và `GetTours`;
  `OperatorRevenueController.cs` là authority của route/query parameter thực tế.
- `Capstone_FE-user-profile-book-tour/specs/UC-44-settled-payout-revenue-fe-spec.md`.
- `Capstone_BE-user-profile-book-tour/specs/DAILY-PAYOUT-TRANSFER-be-spec.md`;
  `OperatorPayoutSettlementsController.cs`, `GetOperatorPayoutSettlementHistoryQuery.cs`,
  `GetPayoutSettlementsQuery.cs` và `PayoutSettlementStatus.cs`.
- Mobile `AGENTS.md`, `CONTRIBUTING.md`, `docs/CODEBASE_RULES.md`.

Khi ví dụ spec/Web cũ lệch DTO đang triển khai, ghi nhận khác biệt; Mobile dùng
contract BE thực tế đã kiểm tra, không tự sửa công thức hoặc tự bù dữ liệu thiếu.

## 2. Mục tiêu và giới hạn

Cho TO đang đăng nhập xem báo cáo của mình, phân tích theo kỳ/tour và tra cứu
các khoản quyết toán trên điện thoại. Dữ liệu live phải đến từ BE đã xác thực.

Trong phạm vi:

1. Đổi nhãn tab Revenue thành **Tài chính**, giữ vị trí tab hiện có.
2. Hai mục con: **Báo cáo doanh thu** và **Lịch sử quyết toán**.
3. UC44: bộ lọc, tổng quan, chi tiết số liệu, biểu đồ một chỉ tiêu và danh sách
   doanh thu theo tour có phân trang.
4. Lịch sử quyết toán phân trang; mở bảng chi tiết từ dữ liệu của từng bản ghi.
5. Loading, empty, lỗi/thử lại, làm mới, phân quyền và khả năng tiếp cận.

Ngoài phạm vi:

- Xuất báo cáo UC45; sửa tài khoản ngân hàng; tạo yêu cầu rút tiền/UC46 legacy.
- Tạo/chạy lại/xác nhận payout, retry transfer, đánh dấu Resolved hoặc thao tác Staff.
- Thay đổi công thức payout, refund, commission, lịch chạy tự động hoặc schema DB.
- Hai danh sách trên dashboard TO, tên doanh nghiệp, các tính năng Traveler.
- BE endpoint mới chỉ để mở chi tiết settlement: hiện chưa cần.

Không hiển thị nút “Rút tiền” hoặc “Xuất báo cáo” từ demo như hành động thật.
Không đặt `NetAmount` dưới nhãn “Số dư khả dụng” hay cho phép rút số tiền đó.

## 3. Bố cục và điều hướng Mobile

### 3.1 Tab Tài chính

- Giữ bottom navigation của OperatorShellPage; hai mục con là segmented control
  hoặc TabBar trong phần nội dung, không thêm một bottom navigation thứ hai.
- Mặc định mở Báo cáo doanh thu. Mỗi mục có trạng thái, bộ lọc, trang và vị trí
  cuộn riêng; chuyển qua lại không tải lại vô điều kiện hoặc mất bộ lọc.
- Chỉ tải một mục khi mở lần đầu. Vào lại Tài chính/foreground làm mới mục đang
  xem; không tạo request lặp khi rebuild. Có nút làm mới thủ công.
  Chuyển hai mục con giữ nguyên trang/bộ lọc/cuộn; refresh thủ công hoặc khi quay
  lại Tài chính/foreground giữ bộ lọc nhưng reset trang 1 và cuộn đầu mục active.
- Bộ lọc/chi tiết là modal bottom sheet có safe area, kéo cuộn và nút đóng.
  Back Android đóng sheet trước; không chặn Back ở shell hoặc tạo vòng điều hướng.
- Không cần thêm route cho từng thẻ tour/settlement trong phạm vi này; giữ route
  `/operator` và tab hiện có. Không dựa vào Navigator pop để đóng cả ứng dụng.

### 3.2 Báo cáo doanh thu, từ trên xuống

1. Tóm tắt kỳ đang áp dụng + tour đang lọc; nút **Bộ lọc** và **Làm mới**.
2. Thẻ **Thực nhận** nổi bật, lấy nguyên `summary.netAmount`. Chú thích:
   “Khoản đã quyết toán trừ hoàn trả đã xác nhận, của các đơn thanh toán trong kỳ”.
3. Bốn thẻ phụ: **Giá trị đặt tour**, **Hoa hồng nền tảng**, **Tiền hoàn**, **Số đơn**.
4. **Xem chi tiết số liệu** mở rộng: GrossRevenue, DiscountsGiven,
   PaymentsReceived, RefundedAmount, NetSales, PlatformCommission, NetAmount,
   TotalBookings, TotalParticipants và CommissionRatePercent do BE trả về.
5. Biểu đồ có chọn một chỉ tiêu: Thực nhận (mặc định), Giá trị đặt tour, Hoa hồng,
   Tiền hoàn. Chạm/chọn một kỳ để xem giá trị và nhãn kỳ, không chỉ dựa vào màu.
6. **Doanh thu theo tour**: danh sách thẻ, 10 tour/trang, nút Trước/Sau và chỉ số trang.
   Tên tour + mã tour, số đơn, giá trị đặt tour và thực nhận hiện ngay. Chạm mở
   sheet xem thêm số khách, tiền hoàn và hoa hồng. Không tạo thêm request chi tiết.

Không dùng bảng nhiều cột kéo ngang làm giao diện chính. Lưới hai cột chỉ khi đủ
rộng; chuyển một cột ở 320dp hoặc khi tăng cỡ chữ. Tên dài, số tiền âm/lớn phải
wrap, không che nội dung hoặc rút gọn giá trị tiền đến mức mất ý nghĩa.

Biểu đồ chỉ hiển thị các bucket BE trả về, giữ thứ tự và `periodKey`/`periodLabel`.
Có danh sách giá trị theo kỳ thay thế cho screen reader. Không tự đổi bucket,
tính lại số tiền, nội suy hoặc tạo bucket 0 rồi trình bày như dữ liệu BE.
Ưu tiên thanh đơn giản bằng Flutter sẵn có; chưa thêm thư viện chart mới.
Trục có mốc 0 và giữ chiều âm/dương; toàn 0 không chia cho 0. Nhiều bucket dùng
viewport cuộn có lazy rendering và danh sách accessible, không tạo một hàng
widget rộng vô hạn hoặc gom/sửa bucket. Test cả số âm, toàn 0 và nhiều kỳ.

### 3.3 Bộ lọc UC44

- Tháng này mặc định, Tháng trước, Khoảng ngày tùy chọn; tour mặc định Tất cả.
- Nhóm kỳ `daily | weekly | monthly`, mặc định monthly, luôn gửi rõ lên BE.
- Ngày API `YYYY-MM-DD`, theo lịch Việt Nam. `endDate` là ngày cuối **bao gồm**;
  BE chuyển thành cận trên đầu ngày kế tiếp. Không gửi epoch hoặc giờ UTC thay ngày.
- Sheet giữ bản nháp; **Áp dụng** mới tải báo cáo và reset trang tour về 1.
  **Hủy/Đóng** không đổi kết quả đang hiển thị. `startDate > endDate` báo lỗi
  ngay tại trường; không gọi API. Không tự đặt giới hạn khoảng ngày chưa được BE quy định.
- Tất cả tổng quan, chi tiết, chart và danh sách tour dùng cùng bộ lọc đã áp dụng.
  Chuyển trang chỉ thay page, không đổi kỳ/tour. Tổng quan/chart không tính từ
  các tour trên trang hiện tại.
  Mỗi page request BE tính lại dữ liệu, không có snapshot/version cố định. Khi
  thành công phải commit nguyên response (summary, chart, tourDetails, metadata
  trang) cùng lúc. Với dataset không đổi, totals độc lập page; khi BE đổi số
  liệu giữa các request, nhận totals mới, không trộn tổng cũ với tour mới.
- Tour options gồm cả tour lịch sử BE trả về; không loại tour vì `isActive=false`.
- Mặc định tháng Việt Nam được lấy từ nguồn thời gian có thể inject vào test;
  ưu tiên kỳ dashboard BE nếu shell đã có snapshot, fallback đồng hồ thiết bị
  UTC+7 chỉ để khởi tạo bộ lọc. Khi test với BE giả lập ngày khác, chọn kỳ bằng
  bộ lọc để khớp; không dùng ngày thiết bị làm nguồn quyết định payout.

## 4. Quy tắc tài chính: BE là nguồn duy nhất

- Revenue cohort theo thanh toán thành công của đơn, giờ Việt Nam; không theo
  ngày đặt, khởi hành hoặc ngày payout. BE chọn canonical payment và eligibility.
- `GrossRevenue` là giá trị trước giảm giá, khác `PaymentsReceived`.
- `NetAmount` là payout Settled trừ phần TO hoàn lại đã có `ReturnReceivedAtUtc`.
  Không tính `NetSales - PlatformCommission` thành thực nhận ở Mobile.
- Đơn mới thanh toán có thể có thực nhận 0 đến khi payout quyết toán; không báo lỗi.
- Trả nguyên số liệu hoàn/commission/net BE cung cấp; không chia 70/20/90%,
  không dùng tỷ lệ commission hiện tại để tính lại lịch sử.
- Ví dụ kiểm thử authority: thanh toán 10.000, hoàn khách 5.000, advance Settled
  7.000, TO trả lại đã xác nhận 3.500, cancellation true-up Settled 1.000:
  thực nhận BE trả về 4.500; Mobile hiển thị đúng 4.500.
- `CommissionRatePercent` là thông tin tổng hợp do BE trả, không là tỷ lệ để Mobile
  nhân tính; không trình bày thực nhận như kết quả của chuỗi trừ kế toán phía trên.
- Định dạng VND nhất quán, giữ dấu âm nếu BE trả về hợp lệ. Không dùng phép tính
  số thực phía client để tạo giá trị tài chính; DTO tiền có thể là số thập phân.
- Số đơn ở báo cáo là `summary.totalBookings` của UC44, có thể khác chỉ số
  “Đơn đặt tour trong tháng” trên dashboard (dashboard lọc tháng tạo đơn).

## 5. Contract UC44 đang có

### GET `/api/v1/operator/revenue/report`

Auth qua central DioClient; chỉ TO được BE cho phép, không gửi operatorId.

Query: `startDate`, `endDate`, `granularity`, `tourId?`, `page=1`, `pageSize=10`.
BE clamp page >=1, pageSize 1..100; Mobile không tự dựa vào clamp để gửi giá trị lỗi.

```text
summary:
  grossRevenue, paymentsReceived, discountsGiven, refundedAmount, netSales,
  platformCommission, netAmount, totalBookings, totalParticipants,
  commissionRatePercent
chartData[]:
  periodKey, periodLabel, grossRevenue, commission, netAmount,
  refundedAmount, bookingsCount
tourDetails[]:
  tourId, tourCode, tourName, bookingsCount, participantsCount,
  grossRevenue, refundedAmount, commission, netAmount
totalToursCount, page, pageSize, totalPages
```

Không có `appliedFilters`, chart start/endDate hoặc `discountAmount` trên từng
tour trong DTO thực tế; không bắt buộc hoặc bịa những trường từ JSON ví dụ cũ.
`summary` và chart áp dụng toàn bộ tập lọc; chỉ `tourDetails` phân trang.

### GET `/api/v1/operator/revenue/tours`

Trả mảng `{id, code, title, isActive}`. Dùng options này cho bộ lọc, không dùng
list tours đang Published để loại tour lịch sử. Lỗi options có thể thử lại riêng;
vẫn cho xem báo cáo Tất cả nếu report load thành công.

## 6. Lịch sử quyết toán (read-only)

### API

GET `/api/v1/operator/payout-settlements?page=1&pageSize=10`.

```text
pageNumber, pageSize, totalCount, items[]:
  settlementId?, batchId?, bookingId, tourOperatorUserId, runDate?,
  kind, payoutAmount, status, transferReference?
```

Query parameter là **page**, response field là **pageNumber**. BE sắp xếp
RunDate giảm dần rồi settlement ID tăng dần; Mobile không đảo thứ tự trang.
Endpoint này **chưa hỗ trợ lọc ngày/trạng thái/tour**, không gửi query giả hoặc
lọc một trang rồi tuyên bố đó là kết quả toàn lịch sử. Không gọi endpoint Admin.

### UI và chi tiết

- Từng thẻ: ngày chạy, loại quyết toán, số tiền, trạng thái và định danh đơn.
  API chỉ có bookingId, không có booking code: hiển thị “Đơn #<bookingId>”,
  không tạo mã BK. SettlementId/batchId hiển thị như ID, không giả mã nghiệp vụ.
- Sheet chi tiết dùng chính row: settlementId/batchId nếu có, bookingId,
  runDate, kind, payoutAmount, status, transferReference. Chỉ cho sao chép mã/ID.
- Null runDate/ID hiển thị “Chưa có”, reference null “Chưa có mã giao dịch”.
  Không tự hiển thị ngân hàng, số tài khoản, timestamp chuyển hoặc lý do lỗi vì
  endpoint không cung cấp. Không request detail API không tồn tại.
- Kind từ BE: `Advance` → Tạm ứng; `Final` → Quyết toán cuối;
  `Cancellation` → Quyết toán hủy tour. Không chỉ hỗ trợ hai giá trị như parser Web cũ.
- Status: Scheduled → Chờ chuyển; Processing → Đang xử lý;
  Settled → Đã quyết toán; SettlementFailed → Chuyển tiền thất bại;
  Resolved → Đã xử lý. **Resolved không đồng nghĩa đã chuyển tiền**.
- DTO dùng chung có thể nhận `Awaiting Window` → Chờ đủ thời gian, nhưng endpoint
  TO hiện không tổng hợp trạng thái này; không tự tạo row cho đơn vừa thanh toán.
- Kind/status chưa biết: nhãn trung tính “Chưa hỗ trợ hiển thị”, không suy ra
  Settled, không mở hành động tài chính; có thể giữ raw token trong Data để chẩn đoán,
  không hiển thị raw token/exception cho người dùng.
- Phân trang Trước/Sau, giữ dữ liệu trang cũ nếu next-page lỗi và retry đúng trang.
  Ngày chạy là calendar date, định dạng nguyên ngày, không timezone-convert gây lệch.

Đây là lịch sử toàn bộ TO. Không có filter tháng báo cáo và không có tổng “thực
nhận trong kỳ” tự cộng từ một trang. Hai phần có thể khác tổng vì cohort/thời
gian và phân trang khác nhau; không coi là lỗi đối soát từ phía Mobile.

## 7. State, lỗi và tính nhất quán

- Mỗi mục có initial/loading/content/empty/failure; lần đầu lỗi có retry rõ ràng.
  Response thiếu field bắt buộc/sai kiểu là lỗi contract, không thay bằng số 0.
- Report không có đơn: hiển thị summary 0 đúng BE, thông báo không có dữ liệu,
  chart/list trống; không tạo số mẫu. Giá trị thực nhận 0 nhưng có đơn là content.
- Filter mới chỉ thay committed state khi report thành công. Khi đang tải bộ lọc
  khác, hiển thị loading, không ghép nhãn kỳ mới vào số liệu cũ. Nếu lỗi, giữ
  committed snapshot cũ với kỳ cũ, chỉ rõ bộ lọc mới chưa được áp dụng và cho retry.
- Mỗi request gắn generation/query identity; response của bộ lọc cũ không được
  ghi đè mới. Chặn double submit/page duplicate; bỏ response sau dispose/sign-out.
- Chuyển trang lỗi giữ trang committed và số liệu hợp lệ; retry không tăng page
  trước khi thành công. Refresh báo cáo reset page 1, giữ bộ lọc đã áp dụng;
  refresh lịch sử reset page 1. Không tự động retry vô hạn.
- 401 đi qua SessionCoordinator hiện có, không thêm refresh loop; 403 hiển thị
  không có quyền, không giả empty; lỗi mạng/5xx báo an toàn + thử lại.
  400 query hiển thị hướng dẫn sửa lọc. Không hiển thị BR/MSG, JSON, stack trace.
- Chỉ giữ state trong phiên; hủy state khi logout/đổi tài khoản. Demo chỉ khi
  được mở explicit theo cơ chế hiện có, có banner; không dùng demo làm fallback live.

## 8. Khác biệt tài liệu/contract đã phát hiện

1. Spec cũ mô tả `RefundedAmount` theo kỳ processed, nhưng aggregator hiện đọc
   refund theo booking canonical, kể cả refund ngoài kỳ/đã xác nhận TO trả lại.
   Mobile hiển thị nguyên giá trị, không tự áp quy tắc cũ; không sửa aggregator ở task này.
2. BE mặc định monthly, một ví dụ spec ghi weekly: Mobile gửi explicit monthly.
3. BE hiện trả 403 cho date range đảo (và không có check ownership tour riêng
   như spec mô tả 403); local validation chặn range đảo, options chỉ lấy owned tour,
   không giả errorCode hoặc sửa BE lẫn vào task. Report query vẫn scope owner.
4. Weekly key hiện ghép calendar year với ISO week number; giao năm có thể khác
   ISO week-year. Mobile không tự tính key thay BE. Ghi nhận kiểm tra BE riêng nếu
   cần sửa; không tuyên bố đã giải quyết quy tắc ISO-week ở Mobile.
5. DTO BE có Cancellation và batchId; parser Web cũ không phải authority để bỏ chúng.

Những điểm này là giới hạn hiện có cần ghi trong kết quả kiểm thử/handoff,
không là giấy phép triển khai quy tắc tài chính mới.

## 9. Kiến trúc và tiêu chí nghiệm thu

Feature `operator_finance`: Domain entities/query/repository; Data source dùng
DioClient, DTO/mapping; Presentation Cubit và widgets. Không import Data vào UI,
không raw Dio trong Cubit, không thêm Provider/GetX, không tính tiền trong widgets.
Hai Cubit độc lập cho revenue/history; tối đa một lớp view điều phối mục đang mở.

1. Chỉ gọi ba GET đã nêu, có auth, không gửi operatorId hoặc mutation.
2. Cùng bộ lọc report dùng cho tất cả sections; commit toàn bộ response mỗi lần.
   Totals độc lập page với fixture tĩnh; dataset thay đổi phải cập nhật nguyên snapshot.
3. Đúng ví dụ NetAmount 4.500, giữ net âm, trường bắt buộc thiếu phải báo lỗi.
4. Date inclusive Việt Nam, preset và year rollover có test; không tự tính lại bucket.
5. Hỗ trợ đủ ba kind settlement, status Resolved không nhầm Settled và unknown an toàn.
6. Back đóng sheet; tab/scroll/filter giữ ổn; loading/lỗi/retry riêng hai mục.
7. Chạy widget tests ở 320dp/390dp, text scale 1.0/1.5/2.0, tên dài/số tiền lớn.
8. Chuyển nhanh filter, next page thất bại, dispose/logout không để dữ liệu cũ ghi đè.
9. Existing operator shell/demo/dashboard tests pass; không thay dữ liệu dashboard
   hoặc hai danh sách chưa được yêu cầu. Không build/cài APK trước khi được yêu cầu.
