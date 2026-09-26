# Windows 1.4.0 — sửa luồng lịch FAP

26/09/2026. Yêu cầu được người dùng làm rõ: mở lịch tất cả lớp → click lớp tại đúng ngày/ca → roster buổi học → Điểm danh/QR; không chọn lớp trước lịch hoặc quay về form khởi tạo phiên.

## Thay đổi

- `SessionSelectionView` điều phối lịch tổng hợp và buổi đang chọn; không có dropdown lớp. Giữ tuần và scroll controller khi quay lại từ roster.
- `WeeklyScheduleGrid` hiển thị mọi lớp trong tuần, kể cả nhiều lớp cùng ô ngày/ca. Mỗi ô mang đủ class + dated slot, không phụ thuộc lựa chọn lớp trước đó.
- `LessonAttendanceView` vào thẳng roster với MSSV/họ tên/email/trạng thái, ngày/ca/lớp đã chốt và nút Điểm danh/Xem mã QR. Xóa `LessonSessionView` cũ. Không tạo phiên khi chỉ click ô lịch.
- `selectLesson` gắn context đồng bộ từ ô lịch, hủy hiệu lực request chọn ca cũ. Có phiên khác đang hoạt động thì không mở nhầm QR hoặc tạo phiên cho lớp khác. Cảnh báo ngày khác hôm nay vẫn giữ trước thao tác mở điểm danh.
- API `weekly_overview` có xác thực, trả tất cả lớp trong một request; cache đọc Sheet chỉ trong request được giữ. Lớp roster trống vẫn xuất hiện nhưng không mở điểm danh mới.
- Sidebar đổi tên thành Lịch giảng dạy. Không đổi dữ liệu roster/lịch/điểm danh thật.

## Kiểm chứng

- 126 Flutter tests pass; test mới kiểm tra hai lớp cùng ngày/ca đều hiện, click lớp thứ hai → đúng roster → chỉ sau click Điểm danh mới mở đúng phiên/QR; không có class selector; quay lại không tải lại lịch.
- 31 backend tests pass, gồm weekly overview có mọi lớp, roster trống và từ chối sai teacher key. Syntax, analyzer, format và architecture checks pass.
- Layout suite 1024/1280/1366/1920 và text scale 100%/150% pass. Render fixture riêng cho lịch hai lớp và roster; ảnh ở build/ui-review/fap-all-classes.png và fap-lesson-roster.png (synthetic, không phải lịch thật).
- Apps Script teacher v18; legacy student v10 không đổi. Kiểm tra remote HEAD bằng v17 trước cập nhật. GET live lần đầu trả ok=false (probe không lưu chi tiết lỗi), lần sau trả ok=true. Không kết luận API luôn ổn định.
- Windows 1.4.0+20260926 ở build/trial-1.4.0, SHA256 `541863BB32D8859D4AF64ED63945D2ACB47BDFFAC278CD784B6DEB4480FE708E`. Shortcut desktop 1.3.0 được đổi thành 1.4.0 và trỏ đúng executable mới.
- Native window 1.4.0 quan sát thấy các lớp SWP391/CSD201 cùng tuần từ Sheet. Người dùng đang tương tác/maximize/chuyển tuần nên ngừng UI automation; không báo đã kiểm thử native click-to-QR hoặc nộp Form.

## Giới hạn dữ liệu giữ nguyên

Lịch/roster vẫn từ Sheet hiện có. Hai roster gốc đi kèm, import cần người dùng xác nhận trong app; chưa tự nhập live. Không tạo lịch SE1913/SE1919 từ file điểm thi. Accepted submission E2E, tỷ lệ vắng cả kỳ và xác nhận lịch chuẩn vẫn là công việc chưa nghiệm thu. Bản này giải quyết luồng điều hướng được sửa lại, không tuyên bố toàn bộ yêu cầu gốc đã xong.
