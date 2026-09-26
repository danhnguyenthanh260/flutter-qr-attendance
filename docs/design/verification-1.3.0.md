# Windows 1.3.0 — lịch tuần và roster

26/09/2026. Tích hợp origin/main bcd85b3 (PR #50) vào feature/startup-navigation-roster, giữ feature folders, lazy IndexedStack, khởi động song song và phục hồi phiên có xác minh. Port các test của PR sang đường dẫn mới. Không nhận lại nhánh xử lý lỗi im lặng khi kiểm tra phiên thất bại.

## Đã triển khai

- Trang đầu là lịch tuần **lọc theo lớp**, ngày × ca; ô lịch mở chi tiết buổi, xem roster/P/A và vào QR. Chuyển tab giữ màn hình và tuần đang xem. Tuần không có dữ liệu được nói rõ và có nút đến tuần có lịch gần nhất.
- Bảng chuyên cần theo các ca của tuần; giữ MSSV từ roster được nhập mới. `—` chưa có phiên, `…` chưa chốt, P có mặt, A sau đóng; kết quả trễ vẫn có thể cập nhật. Chưa tính tỷ lệ vắng cả kỳ.
- Chi tiết khóa lựa chọn lớp/ca đã mở từ lịch. Cảnh báo ngày buổi học khác hôm nay trước khi tạo phiên. Phiên cũ đang mở vẫn truy cập được; không tự đổi ngày hoặc đóng phiên của người dùng.
- `class_overview` có xác thực, trả slots/roster/sessions/attendance theo lớp. Đọc được roster trước khi tạo phiên.
- `import_roster` có xác thực/lock, thêm offering riêng theo lớp–môn–học kỳ, bảo toàn MSSV/MemberCode bằng cột tùy chọn. Chỉ thêm/replay cùng dữ liệu, khác dữ liệu bị từ chối; không xóa roster cũ. Lỗi ghi một phần có thể retry, lớp mới chỉ active khi hoàn tất. Không tạo lịch hoặc Attendance.
- Màn dữ liệu lớp có preview, xác nhận số lượng/lớp/môn/học kỳ trước khi nhập Sheet. Hai file gốc đi kèm release, hash khớp hồ sơ nguồn. **Chưa thực hiện nhập live trong lượt này**.
- Lỗi HTML API có thông báo tiếng Việt, metadata HTTP an toàn; không dùng wifi_off cho mọi lỗi. GET có một retry nằm trong cùng deadline, không replay POST.
- Gateway chỉ đọc mỗi tab một lần trong request, vô hiệu cache khi ghi hoặc lấy lock; không cache giữa các HTTP request. Sửa listSessions truyền nhầm chỉ số Array.map vào classRecord làm sai tên lớp từ phiên thứ hai.

## Kiểm chứng

- 125 Flutter tests pass, gồm test PR #50 được port, matrix trạng thái theo đúng ca/ngày, đọc HTML tạm thời/persistent và các luồng cũ.
- 30 Node tests pass, gồm import replay/conflict/partial write/auth, class overview và cache invalidation.
- Layout checks 1024/1280/1366/1920, text scale 100%/150%; render fixture. Native Windows đã thấy lịch đọc CLASS_001 và preview SE1919 với 37 sinh viên. Chưa bấm xác nhận import hoặc submit điểm danh.
- Backend teacher v17, legacy student v10 giữ nguyên. Remote HEAD kiểm tra v15 trước thay đổi; v16/v17 triển khai cùng teacher URL/access.
- GET class_overview live CLASS_001: 1 slot, 10 roster, 5 sessions, 0 attendance. Một lượt trước tối ưu 32.62s; một lượt sau tối ưu 7.41s. Đây không phải benchmark/đảm bảo SLA; lỗi HTML ban đầu chưa xác định nguyên nhân phía Google.
- Windows build release 1.3.0+20260926, bundle `build/trial-1.3.0`; shortcut desktop đổi từ 1.2.1 sang 1.3.0.

## Còn thiếu để nghiệm thu đầy đủ yêu cầu gốc

- Người dùng cần xem và xác nhận nhập hai roster vào Sheet; email Google dùng để test phải được đối chiếu với roster thật. Chưa có accepted submission E2E.
- Lịch đúng cho SE1913/SE1919 cần nguồn riêng; không tái sử dụng lịch CLASS_001 hoặc tạo lịch từ file điểm thi. Hai tab Slot/ClassSlots cũ còn lệch giờ; UI dùng ClassSlots, chưa sửa dữ liệu này.
- Lịch tuần hiện lọc theo lớp, chưa là lịch tổng hợp tất cả lớp như FAP. Ma trận mới theo tuần; chưa có tỷ lệ vắng cả học kỳ, chưa cố định cột khi cuộn ngang.
- Chưa đóng issues #48/#49; đo hiệu năng nhiều lượt và nghiệm thu dataset/live UI vẫn còn. Không coi build này là hoàn tất toàn bộ yêu cầu gốc.
