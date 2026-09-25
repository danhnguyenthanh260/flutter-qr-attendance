# Khởi động và chuyển màn hình

## Hiện trạng và bằng chứng

Người dùng báo ngày 25/09/2026: **khởi động ít nhất 30 giây**, chuyển tab phải chờ tải lại, ảnh hưởng trực tiếp thao tác giảng dạy. Đây là lỗi trải nghiệm cần xử lý; các mẫu API nhanh hơn không phủ nhận quan sát này.

Probe riêng chỉ đo `classes` 7,677 giây, `slots` 3,531 và 2,375 giây; đọc classes đã cache khoảng 1 ms. Probe thêm nonce/no-cache, không đo full startup, active_session, QR, render hay chuyển tab; không phải benchmark đầy đủ của exe người dùng. Không kết luận toàn bộ 30 giây là cold start Google.

Code kiểm tra: main `842e29d`; ghi riêng WIP closing chưa commit trong clone làm việc. Chưa tái hiện UI 30 giây hoặc xác minh binary đang chạy trùng revision này.

## Đường đi cần đo

- `main.dart`: tạo một attendance service dùng chung cho ba provider.
- `SessionProvider.loadInitialData`: chờ classes, rồi chờ song song slots và restore session. Restore session active còn chờ cấp QR. Loading toàn màn hình kết thúc sau chuỗi này.
- `app_shell.dart`: chỉ mount `_views[_selectedIndex]`, nên chuyển sidebar có thể dispose/recreate màn hình. Provider ở cấp app vẫn sống.
- `AttendanceView`: giữ tab con bằng IndexedStack trong một lần mount; khi rời sidebar rồi quay lại, trạng thái tab con khởi tạo lại.
- Today/History provider có `_isInitialized` guard; SessionSelection chỉ gọi startup khi classes rỗng. Không khẳng định mọi lần đổi tab đều tải lại toàn bộ API.
- Bảng hôm nay có auto-refresh. History đọc danh sách phiên rồi gọi kết quả riêng cho từng phiên. Cần log để tách refresh nền, đổi bộ lọc và tải do mount.
- HTTP service không có deadline chung; close caller timeout 5 giây không hủy request và không chứng minh backend chưa đóng phiên.
- Gateway đọc toàn vùng dữ liệu mỗi sheet rồi lọc trong bộ nhớ. WIP settlement giữ script lock khi đọc; tác động thực tế phụ thuộc đúng deployment được dùng.

## Hướng sửa và phạm vi

Giữ màn hình đã thăm theo cơ chế lazy, giữ tab con/lựa chọn/cuộn; chỉ tải lần đầu hoặc khi stale, người dùng refresh, hoặc có thay đổi phiên liên quan. Không mount sớm tất cả tab gây bão request. Hiển thị snapshot đã có trong lúc refresh, kèm thời điểm cập nhật và trạng thái lỗi nếu có.

Quản lý request đang chạy để coalesce, bỏ kết quả cũ khi đổi scope, điều khiển polling theo trạng thái hiển thị. Cơ chế QR phải vẫn giữ đúng thời hạn và không cấp trùng. Tách dữ liệu cần để màn hình thao tác được khỏi dữ liệu không thiết yếu. Xem xét bootstrap/batch kết quả trên backend, cache có invalidation và giảm đọc sheet lặp; không cache thông tin quyền hoặc xác nhận điểm danh theo cách tạo thành công giả.

## Tiêu chí nghiệm thu đề xuất cho issue

- [ ] Ghi đúng đường dẫn exe, build revision, endpoint/deployment, mạng, số lớp/phiên, có/không active session; log không chứa key, email, token/vé hay URL có credential.
- [ ] Đo từ launch đến first frame, lớp có thể chọn, ca có thể chọn, phiên phục hồi, QR sẵn sàng; có thời gian từng API/hop và tổng số request. Ít nhất 5 lượt khởi động, tách lượt đầu và lượt sau; báo từng mẫu/range, không suy luận p95 từ mẫu quá nhỏ.
- [ ] Có first frame và trạng thái tiến trình trong 2 giây trên máy tham chiếu; không che toàn bộ màn hình để chờ tác vụ phụ. Nếu mạng chậm phải nêu trạng thái chờ/lỗi hữu ích, không báo sẵn sàng giả. Mốc này là mục tiêu, chưa phải kết quả đạt được.
- [ ] Sau tải thành công, chuyển qua lại sidebar/tab con 10 vòng với scope không đổi: giữ tab/bộ lọc/cuộn, nội dung đã có xuất hiện trong 300 ms trên máy tham chiếu; 0 request tải ban đầu lặp chỉ do navigation. Refresh có chủ đích phải được phân biệt trong log.
- [ ] Mỗi scope có tối đa một refresh đang chạy; ẩn tab không gây polling không cần thiết, quay lại làm mới dữ liệu stale theo policy đã ghi.
- [ ] Request có deadline; timeout thao tác ghi không replay POST hoặc tuyên bố thất bại chắc chắn. Đối soát trạng thái an toàn, bảo toàn idempotency và grace period.
- [ ] Kiểm tra slow network, offline/reconnect, classes rỗng, lỗi lần tải đầu, phiên active/closing/closed, đổi lớp nhanh, nhiều phiên và chuyển tab trong lúc tải.
- [ ] Flutter analyze/test, backend check/test nếu đổi backend; đo lại bằng Windows release thật. Test xanh không thay cho mốc thời gian UI và nghiệm thu lifecycle.

Tài liệu này chỉ xác định vấn đề, phép đo và tiêu chí; chưa thay đổi ứng dụng hoặc triển khai Apps Script.
