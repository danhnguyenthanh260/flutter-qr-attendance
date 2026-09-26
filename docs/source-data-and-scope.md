# Dữ liệu lớp và phạm vi có thể triển khai

Cập nhật ngày 25/09/2026. Tài liệu này ghi nhận tài liệu người dùng cung cấp; không chứng nhận các tính năng đã được triển khai hoặc nghiệm thu.

## Nguồn đã kiểm tra

| Nguồn | Nội dung xác minh | Giới hạn |
|---|---|---|
| SE1913 / PRM393 / FALL2026, file `.xls` | 29 sinh viên; Class, RollNumber, Email, MemberCode, FullName; các cột thi/điểm | Không có lịch học, ngày điểm danh hoặc P/A |
| SE1919 / PRN232 / FALL2026, file `.xls` | 37 sinh viên, cùng nhóm thông tin định danh | Không có lịch học hoặc lịch sử chuyên cần |
| Ảnh lịch FAP và trao đổi kèm theo | Tham khảo lịch tuần, từng ca, số sinh viên đã điểm danh; bấm ca xem danh sách và mở QR | Ảnh một thời điểm không xác định lịch cả học kỳ; không phải bản xuất dữ liệu |
| Ảnh bảng chuyên cần | Tham khảo bảng sinh viên × ngày/buổi, P/A, tỷ lệ vắng | Không chép các ô/tên bị mờ thành dữ liệu thật |
| Phản hồi trực tiếp ngày 25/09/2026 | Khởi động ít nhất 30 giây, chuyển tab có cảm giác tải lại | Là quan sát người dùng; cần gắn với đúng exe, phiên bản, trạng thái phiên và log khi tái hiện |

Hai file `.xls` thực tế là XML SpreadsheetML. Đã kiểm tra 66 dòng: không thiếu MSSV/email, không trùng MSSV hoặc email trong từng file. Có 26/29 và 22/37 email ngoài `fpt.edu.vn`; không tự suy ra địa chỉ trường từ MemberCode.

Danh tính lớp–môn–học kỳ lấy từ tên file kết hợp cột Class, cần đối chiếu với ID lớp trong hệ thống trước khi nhập. Không tự gộp các lớp cùng mã nhưng khác môn hoặc học kỳ.

## Đối chiếu bản gốc

- SE1913: `SE1913_PRM393_PHUONGLHK_FALL2026_b496add5-8f4c-4893-8267-cc9d1d2e505a.xls`.
  SHA-256: `28ca3ffc93713ea0a46ff4096d48eef020643e22eeb962cba89c9584be36d34a`.
- SE1919: `SE1919_PRN232_PHUONGLHK_FALL2026_91dce50e-053e-47e5-bc26-142c829ef7db.xls`.
  SHA-256: `45fe48470a08f66724964bf18896b294bcb24109f11954c50066c0ed33e46289`.
- Ảnh gốc: tên bắt đầu `1790151658257_` và `1790153679344_`; cùng ba ảnh clipboard người dùng cung cấp.

Bản gốc nằm trong Downloads của chủ dự án; bản sao đã kiểm tra hash và CSV chuẩn hóa được lưu local trong `.dart_tool/source-intake-2026-09-25/` của working clone. Đây không phải kho lưu trữ lâu dài: trước khi xóa cache cần giữ bản gốc hoặc chuyển sang vùng lưu trữ hạn chế truy cập đã xác minh. Repository hiện public; không commit bản gốc, CSV sinh viên hoặc ảnh có thông tin cá nhân. Chưa có liên kết kho nguồn chia sẻ được xác minh.

## Có thể làm ngay từ các nguồn này

1. Xây bộ đọc SpreadsheetML, xem trước dữ liệu, kiểm tra trùng/thiếu và báo lỗi từng dòng. Giữ MSSV/MemberCode dạng chuỗi, bảo toàn dấu tiếng Việt, chỉ chuẩn hóa email để so khớp.
2. Thiết kế mapping danh sách vào roster theo lớp–môn–học kỳ; cho xem chênh lệch trước khi nhập, nhập lặp không nhân bản, không xóa roster cũ ngầm. Đây là công việc có thể triển khai; chưa nhập dữ liệu vào Sheet thật.
3. Xây màn hình danh sách sinh viên trước khi có phiên điểm danh. API hiện trả roster qua kết quả phiên, nên cần bổ sung contract đọc roster theo lớp, có xác thực giáo viên.
4. Đặc tả lịch tuần → chọn ca → danh sách sinh viên → mở QR, với số đã điểm danh/tổng số và trạng thái phiên. Có thể dựng giao diện bằng fixture ghi rõ là dữ liệu thử; dữ liệu lịch thật phải có nguồn.
5. Sửa tải chậm, giữ lựa chọn/bộ lọc/vị trí cuộn khi đổi tab, hiển thị dữ liệu đã có trong lúc cập nhật. Không phụ thuộc vào lịch hoặc bảng P/A mới.

## Chưa đủ để kết luận

- Lịch cả kỳ, phòng, giáo viên, múi giờ, ngày nghỉ/bù và tổng số buổi: cần bản lịch có cấu trúc và quy tắc thay đổi.
- P/A lịch sử: cần bản xuất chuyên cần hoặc Attendance đã xác minh; không dùng file điểm thi làm lịch sử điểm danh.
- Cấm thi/ngưỡng vắng: cần quy chế, tổng số buổi, cách tính nhiều phiên cùng buổi và trạng thái đã chốt. Không mặc định 20 buổi hoặc ngưỡng 20% chỉ từ code nhánh AI.
- Email trong roster và email tài khoản Google xác thực có thể khác nhau: cần quy tắc đối chiếu; không tự thay địa chỉ hoặc tự ghép sinh viên.
- Ảnh là tham khảo luồng, không tự cho phép thao tác điểm danh thật, thay Form/Sheet hoặc gửi dữ liệu sinh viên tới AI.

## Liên kết công việc

- [#49 — Roster và luồng lịch tuần → danh sách → QR](https://github.com/danhnguyenthanh260/flutter-qr-attendance/issues/49).
- [#48 — Khởi động và chuyển tab chậm](https://github.com/danhnguyenthanh260/flutter-qr-attendance/issues/48).

Xem [contract dữ liệu](contracts.md), [yêu cầu báo cáo](ai-reporting-requirements.md), [nghiệm thu tốc độ](performance-and-navigation.md). Issue và kết quả kiểm thử phải phân biệt: có code, đã tích hợp, đã deploy, đã nghiệm thu.
