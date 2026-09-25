# Nghiên cứu hệ thống và hướng thiết kế

Ngày nghiên cứu: 25/09/2026. Người dùng đã đồng ý hướng nghiên cứu kiến trúc/UI và yêu cầu dùng ImageGen khi cần, lấy cảm hứng từ `Downloads/download (1).jpg`. Đây là nghiên cứu tài liệu sản phẩm chính thức và concept hình ảnh, chưa phải thử trực tiếp các tài khoản LMS hoặc bản UI Flutter đã triển khai.

## Các hệ thống tham khảo

| Hệ thống / nguồn chính thức | Quan sát được | Áp dụng vào app | Giới hạn |
|---|---|---|---|
| [Canvas Roll Call](https://community.instructure.com/en/kb/articles/662770-what-is-the-roll-call-attendance-tool) | Attendance gắn với course, có cách xem danh sách/sơ đồ chỗ ngồi và tích hợp Gradebook | Luôn giữ ngữ cảnh lớp/buổi cạnh bảng sinh viên; hành động điểm danh nằm trong ngữ cảnh đó | Không đưa tính điểm chuyên cần hoặc sơ đồ chỗ ngồi vào phạm vi hiện tại |
| [Moodle Attendance](https://supportus.moodle.com/support/solutions/articles/80001015473-using-the-attendance-module-in-moodle) | Giáo viên quản lý attendance theo từng session và trạng thái sinh viên | Buổi học là đơn vị của lịch sử; bảng cần lọc trạng thái, điều hướng ngày rõ | Không tự thêm Late/Excused khi backend chưa hỗ trợ; chưa điểm danh trong phiên mở không phải vắng |
| [Google Classroom Teacher Center](https://edu.google.com/intl/ALL_tr/for-educators/product-guides/classroom/) | Tách các công việc Classwork, People và Grades trong một lớp | Navigation dùng tên công việc giảng viên, bỏ tên người phát triển; thông tin lớp giữ ổn định khi chuyển nội dung | Classroom không được dùng làm bằng chứng về một luồng QR attendance có sẵn |
| Ảnh FAP người dùng cung cấp trước đó | Kỳ vọng chọn slot → xem danh sách → mở QR | Hướng tổng thể chọn buổi rồi làm việc trên danh sách | Ảnh không cung cấp dữ liệu lịch học hay lịch sử điểm danh để nhập |

Đề xuất tổng hợp: lớp/buổi là ngữ cảnh chính, danh sách là bề mặt thao tác, QR là chế độ trình chiếu riêng, lịch sử là tra cứu. Không biến ứng dụng nhỏ thành LMS đầy đủ.

## Tham chiếu thị giác và quyền sử dụng

- Đã mở đúng ảnh `C:/Users/danhn/Downloads/download (1).jpg`, 736×920: poster retro, nền kem hồng, chữ lớn xanh xám, xe mint và cỏ olive.
- SHA-256: FA7F4E6A0576A51D77FD2CCA67C5E2DC1CF146C9BC74B6E459E1B2997E3405DD.
- Chỉ lấy cảm hứng từ màu/nhịp chữ/chất giấy. Không dùng nguyên ảnh, xe, tên tác giả hay poster như asset sản phẩm. Bản gốc giữ ở Downloads, không đưa vào public repo.
- Đã kiểm tra inventory dei8: phần lớn là React/SVG minh họa du lịch, chưa có primitive Flutter phù hợp; không kéo dependency React vào ứng dụng.

## Hướng được chọn để phát triển

Tên làm việc: retro nhẹ cho công cụ giảng viên. Nền ấm, chữ slate tương phản cao, mint làm vùng nhấn, teal cho CTA. Texture chỉ nằm trong minh họa; bảng và QR dùng nền sạch.

| Token đề xuất | Giá trị | Vai trò |
|---|---|---|
| canvas | #FFF8F5 | Nền chính |
| surface | #FFFFFF | Bảng, dialog, vùng QR |
| ink | #344658 | Chữ chính |
| action | #285D61 | CTA/focus |
| mint | #DCECE5 | Vùng chọn/tóm tắt |
| accent | #9AA46B | Điểm nhấn trang trí nhỏ, không làm chữ nhỏ |
| border | #D8DCD9 | Phân cách |

Thông số này là đầu vào thiết kế, chưa phải chứng nhận contrast. Kiểm tra tương phản, text scale và bản Windows trước khi nghiệm thu. Giữ Segoe UI cho bảng/controls; nếu dùng serif thì chỉ cho tên sản phẩm/heading nhỏ, cần kiểm tra đủ dấu tiếng Việt. Title màn hình thật khoảng 28–36 px, không dùng kích thước poster.

## Asset đã tạo và đánh giá

1. `lecturer-retro-concept-v1.png`: ImageGen tạo concept 1536×1024, đã xem toàn ảnh; số liệu và sinh viên đều là minh họa, có nhãn. Dùng để định hướng màu sắc và bố cục, không làm nền ảnh thay cho UI tương tác.
2. `../../assets/illustrations/roster-empty-retro-v1.png`: ImageGen tạo riêng sổ danh sách và bút mint không chữ; dành cho empty state hoặc hướng dẫn nhập file, kích thước hiển thị dự kiến 120–160 px. Chưa khai báo asset vào pubspec vì chưa triển khai UI.

Điểm cần sửa khi chuyển concept thành code: bỏ các câu trích dẫn tự sinh, bỏ tranh bên cạnh bảng đang có dữ liệu, giảm heading và khoảng trống đầu trang; bỏ checkbox/menu hàng nếu chưa có thao tác thực; không dùng số demo, phân trang hay trạng thái demo trong app. Nút phải theo trạng thái thực: chưa mở → Mở điểm danh; đang mở → Trình chiếu QR; đang chốt → tiến trình. Concept v1 thể hiện số đã điểm danh cùng CTA mở phiên nên không được sao chép logic đó.

Icon chức năng tái sử dụng Material của Flutter: lớp `groups_outlined`, lịch sử `history`, dữ liệu `folder_open`, QR `qr_code_2`, đồng bộ `sync`, cảnh báo `error_outline`. Kích thước 20–24 px, trạng thái chọn có cả nền và chữ. ImageGen không tạo từng icon bitmap nhỏ; QR thật luôn được dựng từ payload server bằng qr_flutter.

## Kết nối kiến trúc

Giữ hướng trong ../ui-architecture-brief.md: view model chịu state màn hình; repository chịu nguồn dữ liệu/cache; QrController chịu hạn/retry/timer. Shared components: PageHeader, FilterBar, SessionSummary, SyncStatus, StatusBadge, AttendanceTable và EmptyState. Không thay Provider chỉ vì thay phong cách giao diện.

Triển khai trên API hiện có trước. Bảng roster trước khi mở phiên cần API roster theo lớp; lịch tuần cần nguồn lịch thực. Trong khi chưa có, màn hình dữ liệu từ file phải giữ nhãn preview và trạng thái chưa mapping. Không dùng asset hoặc thiết kế đẹp để che lỗi mạng/trạng thái chưa xác minh.

## Phạm vi bước tiếp theo

Render component độc lập ở loading/empty/error/success; ghép shell và chọn lớp/ca; ghép QR và bảng; sau đó tách controller/repository từng bước. Kiểm tra 1024×768, 1280×720, 1366×768, 1920×1080 và scale125/150%, bàn phím, tên dài, giữ tab/cuộn và không tăng request. Giữ nguyên các kiểm thử an toàn QR vừa thêm.
