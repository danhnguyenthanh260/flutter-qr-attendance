# Research: dữ liệu thật và luồng FAP

Ngày kiểm tra: 26/09/2026. Phạm vi: đọc source, hai file gốc, Google Sheet và GET API. Không chạy extension tự động, tạo phiên, submit Form, sửa Sheet, merge hoặc deploy. Source local 6cbf224; origin/main bcd85b3.

## Kết luận dữ liệu

Hai file Downloads được đọc lại bằng XML SpreadsheetML, hash khớp hồ sơ `docs/source-data-and-scope.md`:

| Nguồn | Dữ liệu xác minh | Giới hạn |
|---|---|---|
| SE1913_PRM393…xls, Sheet1 | 29 sinh viên; MSSV/email đầy đủ, không trùng trong file | Cột định danh và điểm thi; không có lịch/P/A |
| SE1919_PRN232…xls, Sheet1 | 37 sinh viên; MSSV/email đầy đủ, không trùng trong file | Không có lịch/P/A; mã môn/học kỳ từ tên file |
| Test_PRM392 / Classes | 6 lớp CLASS_001–006; PRM392/SWP391/CSD201 | Không có lớp SE1913–PRM393 hoặc SE1919–PRN232 |
| Roster A1:H100 | 60 dòng, 10 mỗi lớp | Schema không có RollNumber, MemberCode, học kỳ |
| Slot và ClassSlots A1:L30 | 6 ca ngày 20–21/09 | Hai nguồn lệch giờ: ca đầu 07:30–09:00 so với 07:54–09:24 |
| Sessions A1:M60 | 5 phiên; phiên mới nhất mở 26/09, session_date 20/09, đang active | Mở phiên từ lịch cũ; ngày mở không phải ngày buổi học |
| Attendance A1:L30 | Chỉ header | Chưa có lượt chấp nhận trong vùng đọc |
| FormResponses A1:L30 | 3 phản hồi, đều email_not_in_roster | Lượt 26/09 dùng token FORM_ mới; chứng minh đã tới xử lý, chưa phải accepted |

Sheet: https://docs.google.com/spreadsheets/d/1VCiJlRCH3Z036-7ksjT3rAtpmAVmp4kytUWcaGSOhpk/edit . Không đưa tên/email/token sinh viên vào báo cáo. Các phạm vi đọc có hàng trống sau dữ liệu; không lấy grid rowCount làm số bản ghi.

Không được suy ra email nào trong hai roster phù hợp với người nộp bị từ chối. Cần mapping có xác minh giữa MSSV, email nguồn và email Google xác thực. Giữ dữ liệu cũ theo lớp riêng; không ghi đè CLASS_001 bằng lớp mới.

## FAP: nguồn tham khảo có thể dùng

Source đọc tại D:/Coding_learning/fap-auto-attendance: content-fap.js, content-activity.js, content-attendance.js, background.js, popup.js và README.md. Chưa kiểm thử UI FAP đang đăng nhập; kết luận dưới đây là code và ảnh nguồn, không phải chứng nhận live.

- content-fap.js tìm bảng MON–SUN, nhận slot Not yet, lấy lớp/giờ/activity URL. Chọn lịch là điểm vào tự nhiên.
- content-activity.js nối ActivityDetail → Take. content-attendance.js tìm bảng có cột Present rồi Save.
- README còn mô tả đường EduNext cũ; source hiện mở activity URL. Source hiện hành được ưu tiên khi mô tả hành vi.
- Extension có thao tác chọn Present cho toàn bộ roster và trả success trước khi Save hoàn tất. Không dùng thao tác này hoặc số radio đã chọn làm bằng chứng điểm danh QR thành công.
- Hàm xác định hôm nay dựa vào thứ trong tuần; không nên sao chép nguyên logic vào app khi đang xem tuần khác.

## Luồng sản phẩm đề xuất theo ảnh

Lịch tuần → chọn một buổi cụ thể → danh sách lớp và chuyên cần → mở phiên/hiện QR → theo dõi kết quả → đóng phiên → quay lại đúng tuần/ô đã chọn.

| Màn hình | Quyết định | Bố cục và trạng thái |
|---|---|---|
| Lịch giảng dạy | Thay màn chọn lớp/ca làm trang vào chính | Cột thứ/ngày, hàng slot; bộ chọn tuần/năm; lớp–môn–phòng–giờ; số đã nhận/tổng roster; trạng thái chưa mở/đang mở/đang đóng/đã đóng |
| Chi tiết buổi | Tạo từ ô lịch, không yêu cầu chọn lại lớp/ca | Breadcrumb về tuần; đúng roster kể cả chưa có phiên; nút mở QR; nhãn ngày buổi học rõ ràng |
| Bảng chuyên cần | Phát triển bảng hiện có thành sinh viên × buổi | Cố định MSSV/họ tên và header ngày; P/A/Chưa chốt/Chưa có dữ liệu khác nhau; tỷ lệ vắng chỉ khi quy tắc mẫu số được xác nhận |
| Trình chiếu QR | Giữ màn/controller hiện có | QR lớn, lớp/ca/ngày, deadline, trạng thái nhận dữ liệu; lỗi không tự kết luận phiên thất bại |
| Dữ liệu lớp | Giữ nhưng hoàn thiện preview → mapping → diff → import | Báo dòng thiếu/trùng; không có mã kỹ thuật bắt giáo viên tự nhập; không tự xóa roster cũ |

Ưu tiên bố cục bảng gọn và mật độ như ảnh FAP; không dành phần lớn cửa sổ cho card trang trí. Giữ tuần, lớp, buổi và vị trí cuộn khi quay lại. Khi refresh, giữ dữ liệu cũ cùng thời điểm cập nhật; lỗi nằm ở vùng ảnh hưởng. Không dùng màu đơn độc để phân biệt P/A.

## Architecture và component

Giữ Flutter Material/Material Icons, Provider và repository hiện có. Không cần image generation hay bộ icon mới cho nghiệp vụ bảng.

- Có sẵn: features/teaching, attendance, qr, roster_import; CatalogRepository, QrController, bảng roster và notice.
- RosterImportViewModel hiện chỉ đọc file/preview; chưa ghi roster backend.
- Cần contract dữ liệu cho course offering (lớp–môn–học kỳ), scheduled lesson (ngày–ca–giờ–phòng), enrollment có MSSV và định danh Google, liên kết session với lesson.
- Cần đọc roster độc lập với session, lịch theo tuần, tổng hợp chuyên cần theo lesson; tránh một API call cho mỗi ô lịch.
- Component đề xuất: WeekSelector, WeeklyScheduleGrid, LessonCell, LessonHeader, AttendanceMatrix, AttendanceStatusCell, RefreshStatus. Dùng lại Material controls cho date picker/dialog/menu.
- DataTable đủ cho preview 29–37 dòng. Bảng chuyên cần nhiều cột cần prototype TableView để cuộn hai chiều/cố định trục, kiểm tra hiệu năng rồi mới chọn dependency.

## Lỗi API và code integration

GET sessions(class_id=CLASS_001,date=2026-09-26) trong lượt research trả HTTP 200, application/json, ok=true, khoảng 11.875 giây; không tái hiện được invalid JSON. Đây là một phép đo bằng Python HTTP, không phải benchmark Flutter hoặc nguyên nhân đã chốt.

GoogleAppsScriptAttendanceService giải mã JSON trước phân loại HTTP lỗi, nên phản hồi HTML mất thông tin chẩn đoán. AttendanceStateMessage.error dùng wifi_off cho mọi lỗi. Cần metadata chẩn đoán an toàn (status/type/host/thời gian/request id), không log teacher key hoặc toàn bộ URL redirect. Phân biệt network/timeout/auth/service/invalid_response.

GitHub: không có PR đang mở tại thời điểm kiểm tra; #50 đã merge vào main. #48/#49 vẫn mở. Bản local có architecture và QR riêng chưa tích hợp main mới. #50 sửa đường dẫn provider/view cũ; cần reconcile hành vi với feature folders hiện tại, không chỉ merge cơ học.

## Thứ tự triển khai và nghiệm thu

1. Chốt nguồn lịch chuẩn và mapping hai course offerings; giữ các lớp cũ. Import preview phải đúng 29 + 37 sinh viên, không mất MSSV/MemberCode, không nhân bản khi nhập lại.
2. Reconcile #50 với local; sửa chẩn đoán API/UX lỗi. Đo cold/warm startup và tab switching, không dùng 1 request thành công để đóng #48.
3. Contract lịch/roster/lesson results, sau đó component lịch và chi tiết buổi. Có dữ liệu lịch chỉ ngày 20–21 thì tuần khác hiển thị thiếu dữ liệu, không bịa lịch.
4. Ma trận chuyên cần; thống nhất nhiều session trong một lesson, thay roster giữa kỳ và trigger trễ trước khi tính tỷ lệ vắng.
5. E2E bằng tài khoản Google thuộc roster được xác minh: Form → accepted Sheet row → đúng ô buổi → counter. Bao gồm expired/duplicate/late trigger và mất mạng. Không sửa điểm danh thật trong giai đoạn research.
6. Kiểm tra 1280×720, 1366×768, 1920×1080, text scale 150%, bàn phím; build gắn source/backend identity và một shortcut.

## Nguồn UX / thư viện

- NN/g, Visibility of System Status: https://www.nngroup.com/articles/visibility-system-status/ — giữ trạng thái/cập nhật rõ ràng; thành công phải có xác nhận.
- Material canonical layouts: https://m3.material.io/foundations/layout/canonical-examples/overview — navigation và vùng chi tiết nhất quán.
- Flutter DataTable: https://api.flutter.dev/flutter/material/DataTable-class.html — giới hạn chi phí layout; TableView là phương án cho bảng lớn.
- Nguồn sản phẩm chính: ảnh lịch và ma trận FAP người dùng cung cấp, đối chiếu với source extension nêu trên. Không lấy mẫu dashboard chung thay thế bố cục này.
