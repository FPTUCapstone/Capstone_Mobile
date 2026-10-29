# TM-70 Search V2 trên Development/Staging

Search legacy `/api/v1/tours` giữ nguyên khi cờ tắt (mặc định). Search V2 chỉ bật khi `TM70_DEV_SEARCH_V2=true`, `APP_ENV=development|staging` và có `TM70_DEV_SEARCH_KEY` tạm thời. Production luôn bỏ qua cờ. Backend vẫn phải kiểm tra môi trường và access key; cấu hình client không thay thế authorization phía server.

Truyền cấu hình bằng Dart defines của môi trường lab: `API_BASE_URL`, `APP_ENV`, `TM70_DEV_SEARCH_V2`, `TM70_DEV_SEARCH_KEY`. Không commit file chứa key, không đưa key thật vào command history/evidence hoặc phát hành binary lab. Dart define nằm trong binary nên chỉ dùng credential tạm thời, giới hạn môi trường lab và thu hồi sau test. Dùng HTTPS trên staging được phép; local HTTP chỉ cho mạng lab/loopback đã duyệt. Android emulator dùng địa chỉ host phù hợp thay cho loopback của thiết bị.

Client gọi `GET /api/dev/tours/search` và `GET /api/dev/tours/categories`, gửi header `X-TM70-Dev-Key` riêng cho hai route; không theo redirect. UI giữ các thành phần hiện có, bổ sung keyword, lexical/semantic/hybrid, sort canonical, date range, duration, category và minimum rating 1–5. Category lấy code/name từ server, không lưu taxonomy cố định. Rating null không chuyển thành 0; rating có giá trị được hiển thị nguyên giá trị server. SQL phía Backend quyết định eligibility và business filters. Response cũ bị bỏ qua khi truy vấn đổi; lỗi giữ kết quả đã có và không nối trang sai truy vấn.

Semantic không threshold và RRF k=60 thuộc cấu hình functional smoke trên Backend, không là quyết định relevance/production. Corpus giới hạn 256 và thiếu/stale vector phải trả lỗi từ Backend; client không cắt kết quả hay tự dựng totalCount.

## Kiểm thử pipeline thật

`test/features/tour_search/dev_search_live_test.dart` là harness opt-in dùng chính Cubit, use case, repository và Dio của ứng dụng. Mặc định skip để unit test không chạm dịch vụ. Nó chỉ gửi HTTP GET; không khởi động provider hoặc tạo/sửa/xóa SQL.

Thiết lập biến môi trường trong process test: `TM70_MOBILE_LIVE_E2E=1`, `TM70_E2E_URL` (loopback của Backend lab), `TM70_E2E_KEY_FILE` (file riêng bên ngoài Git chứa credential tạm thời), và tùy chọn `TM70_E2E_QUERY` phù hợp corpus seed. Chạy `flutter test --no-pub test/features/tour_search/dev_search_live_test.dart`. Không in nội dung key. Corpus seed cần ít nhất một lexical match cho câu query và có vector đầy đủ/fresh. Harness kiểm tra ba mode, pagination/deduplication, categories và bộ lọc trả rỗng hợp lệ.

Harness là bằng chứng client API/Cubit E2E, không thay cho kiểm thử UI trên điện thoại thật. Chỉ ghi PASS khi đã chạy với provider thật; skip không phải thành công pipeline. Không dùng kết quả dev để đóng SEM-D1–D5 hoặc kích hoạt production.
