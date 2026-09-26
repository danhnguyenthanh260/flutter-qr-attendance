# Contract điểm danh và dữ liệu lớp

## Cập nhật deployment v15 (25/09/2026)

Người dùng đã duyệt QR mở thẳng Google Form: mã đổi mỗi 30 giây, hạn nộp 120 giây từ lúc phát hành, xét timestamp của Google Form. Giữ email xác thực, roster, chống trùng và tương thích grant cũ. Chi tiết, bằng chứng kiểm thử và giới hạn nghiệm thu tại [Direct Form QR](direct-form-qr.md). Phần dưới ghi nhận baseline trước thay đổi này.

Cập nhật 25/09/2026. Phân biệt rõ contract đang có trong main `842e29d` và phần cần bổ sung; không coi issue đã đóng là bằng chứng mọi tiêu chí đã đạt.

## Đang có trong source

- Flutter gọi teacher API có kiểm tra teacher key; GET: `classes`, `slots`, `active_session`, `sessions`, `session_results`; POST: `start_session`, `close_session`, `issue_qr`.
- Mở phiên có request_id để nhận diện thao tác lặp. QR theo thế hệ → claim → grant → Google Form → Form response → xử lý Attendance/Attempts. Phải phân biệt thời điểm claim, thời điểm Forms nhận submit và lúc trigger xử lý.
- Envelope trả `ok` và `data` hoặc `error`; kết quả phiên chứa session, roster, attendance và attempts. Client cần chấp nhận đúng payload của deployment thực tế.
- `active`, `closing`, `closed` là các trạng thái khác nhau. Chưa điểm danh trong active/closing không được tự kết luận là vắng đã chốt. WIP đang sửa đóng/mở lại chưa commit vào main; phải kiểm thử riêng trước tích hợp.
- QR xoay không chứng minh sinh viên hiện diện; không tuyên bố đã chống được chuyển tiếp ảnh QR còn hạn.

## Roster từ dữ liệu mới

Nguồn và giới hạn tại [Dữ liệu lớp](source-data-and-scope.md). Mapping đề xuất: Class → lớp nguồn; RollNumber → MSSV giữ dạng chuỗi; FullName → tên hiển thị; Email → địa chỉ gốc và email_key chuẩn hóa; MemberCode → mã tham chiếu. Môn/học kỳ trong tên file cần xác nhận với class_id hiện có.

Chưa có endpoint roster độc lập theo lớp trong teacher API hiện tại. Để mở danh sách trước khi tạo phiên, cần thiết kế endpoint có quyền giáo viên; không mở phiên giả chỉ để đọc roster. Import phải xem trước, kiểm tra định danh, mapping lớp và xử lý xung đột; không thay roster cũ hoặc dữ liệu lịch sử tự động.

## Lịch tuần và bảng chuyên cần cần bổ sung

Luồng tham khảo: tuần → ca học → danh sách sinh viên → nút điểm danh mở QR. Cần định danh lớp–môn–học kỳ–ngày–ca, thời gian/phòng nếu có nguồn, liên hệ tới một hoặc nhiều phiên và trạng thái tổng kết. Không tự tạo cả kỳ từ một ảnh lịch.

Roster có thể có trước phiên; ô chuyên cần cần phân biệt chưa có dữ liệu, chưa điểm danh, còn xử lý, có mặt và vắng đã chốt. Cách gộp nhiều phiên trong một buổi và roster thay đổi giữa kỳ phải được chốt trước khi tính tỷ lệ học kỳ.

## Các quyết định chưa thống nhất

- Issue #6 nói không cần đăng nhập Google, nhưng PR #35 đã chuyển sang email Google Form xác thực. Giữ Form hiện có; cần thống nhất yêu cầu và mapping email thay vì tự tạo lại Form hoặc hạ xác thực.
- Grace period và thời điểm chốt phải đọc từ cấu hình/quyết định đã xác nhận; không lấy screenshot làm quy tắc.
- Số buổi, ngưỡng cấm thi, lịch thật và lịch sử P/A chưa có trong hai roster mới.
- Báo cáo aggregate có filters/as_of/provenance là yêu cầu của #17, chưa phải endpoint đã cung cấp. Xem [Yêu cầu báo cáo](ai-reporting-requirements.md).

## Nghiệm thu xuyên suốt

Kiểm thử QR giây 29 → submit giây 40 theo grace thực tế; nhiều người dùng cùng QR; vé sửa/hết hạn/đã dùng; submit trùng và trigger chạy lại/trễ; lỗi ghi một phần; closing → closed → mở lại; đọc khác lớp/ngày; roster thiếu; offline/timeout mà không replay POST. Bằng chứng phải ghi source revision, deployment và consumer build. Không dùng sinh viên giả trong dữ liệu thật để thay cho fixture test.
