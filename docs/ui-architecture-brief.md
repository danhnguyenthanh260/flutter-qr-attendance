# Đề xuất kiến trúc và UI/UX giảng viên

Ngày 25/09/2026. Trạng thái: đề xuất để duyệt hướng thiết kế, chưa triển khai lại giao diện.

## Mục tiêu

Giảng viên tìm lớp/buổi cần dạy, xem danh sách, mở QR và theo dõi số người đã điểm danh với ít thao tác. Ưu tiên Windows desktop, giữ Flutter, Material và Provider hiện có. Không đưa dữ liệu điểm danh hoặc lịch học suy đoán vào màn hình.

## Chẩn đoán từ code và bản Windows

- AppShell dùng sidebar cố định 260 px; nhãn Người 1/2/5 là phân công kỹ thuật, không phải thông tin giảng viên cần.
- Tiêu đề dài, nhiều thẻ lớn và màu trạng thái cạnh tranh với hành động chính. Khối thông tin phiên lặp nội dung lớp/ca; mã phiên kỹ thuật chiếm diện tích.
- SessionProvider sở hữu chọn lớp, tải ca, phục hồi phiên, lưu máy, timer QR và xử lý mạng. Thay giao diện dễ vô tình tác động vòng đời QR.
- GoogleAppsScriptAttendanceService gộp HTTP/redirect, cache danh mục và giữ request ID. Roster preview đọc file trực tiếp trong view; logic này cần có view model riêng.
- Đã có AppColors/AppTypography và các widget bảng, chip, empty/error state để tái sử dụng. Giữ cơ chế lazy IndexedStack vừa sửa để chuyển tab không tải lại.

## Sơ đồ trải nghiệm đề xuất

```text
Lớp học & buổi dạy
  └─ Chọn lớp / ca thực sự có trong dữ liệu
      └─ Chi tiết buổi: danh sách sinh viên + tiến độ + Mở điểm danh
          ├─ Trình chiếu QR: mã lớn, hạn thật, trạng thái kết nối
          └─ Kết thúc: xác nhận → đang chốt → kết quả
Lịch sử: lọc lớp/ngày → chọn buổi → bảng kết quả
Dữ liệu lớp: xem file nhập và tình trạng mapping
```

Không gọi dữ liệu ca ngày 20/09 là “Hôm nay” vào ngày 25/09. Lịch tuần là phần mở rộng sau khi có nguồn lịch thật. Roster từ file chưa mapping phải ghi rõ chưa đồng bộ; không trộn với roster server. AI placeholder không phải một đích điều hướng chính cho tới khi tính năng hoạt động.

## Bố cục màn hình chính để duyệt

```text
┌────────────────┬──────────────────────────────────────────────────────┐
│ Điểm danh      │ Lớp học & buổi dạy               Ngày / trạng thái   │
│                ├──────────────────────────────────────────────────────┤
│ Lớp & buổi dạy │ [Chọn lớp] [Chọn ca/ngày]                             │
│ Lịch sử        │ Tên môn · mã lớp · ca · phòng                         │
│ Dữ liệu lớp    │ Đã điểm danh / sĩ số                [Mở điểm danh]    │
│                ├──────────────────────────────────────────────────────┤
│                │ Tìm sinh viên...    [Tất cả / Đã / Chưa]              │
│                │ MSSV       Họ tên              Trạng thái             │
│                │ ...                                                   │
│ Phiên bản      │ Cập nhật lúc …                         [Làm mới]       │
└────────────────┴──────────────────────────────────────────────────────┘
```

Đây là cấu trúc mục tiêu. Bảng trước khi mở phiên cần endpoint roster theo lớp; hiện API chỉ trả roster trong session_results. Bản cải tiến đầu giữ màn hình chọn lớp/ca đang chạy, làm gọn và thống nhất component; không giả lập bảng chưa có API.

## Hệ thống UI

- Nền sáng trung tính, một màu xanh cho hành động chính; màu đỏ chỉ cho lỗi và kết thúc phiên. Giảm card lồng card, giảm badge không cần thiết.
- Khoảng cách 4/8/12/16/24/32; nội dung 14–16 px; bảng hàng khoảng 44–48 px; tiêu đề 24 px; bo góc nhất quán 10–12 px.
- Thành phần dùng chung: PageHeader, SectionSurface, FilterBar, SyncStatus, StatusBadge, EmptyState, InlineError, roster table và xác nhận kết thúc.
- Thông tin kỹ thuật, request ID và chẩn đoán chỉ trong phần chi tiết hỗ trợ. Không hiển thị quyền Admin nếu chưa có dữ liệu danh tính thật.
- Dữ liệu đã tải vẫn hiện khi refresh; lỗi đặt cạnh vùng bị lỗi. QR có trạng thái riêng: đang lấy / còn hạn / đang phục hồi / hết hạn / dừng.
- Bàn phím: thứ tự Tab hợp lý, focus rõ, Enter cho hành động chọn, Escape thoát dialog/trình chiếu; nút kết thúc không là default Enter.
- <=1100 px thu gọn navigation và xếp khối thông tin theo chiều dọc; bảng cuộn ngang bên trong; trình chiếu ưu tiên diện tích QR, ẩn navigation.

## Kiến trúc đề xuất

```text
Views + shared Material components
  ↓
ViewModels (Provider/ChangeNotifier)
  ├─ ClassSelection / Results / History / RosterImport
  └─ SessionCoordinator + QrController
  ↓
Repositories: Catalog / Session / Attendance / LocalRoster
  ↓
TeacherApiClient (HTTP, envelope, redirect, timing) + local storage
```

Giữ Provider; không đổi sang Bloc/Riverpod chỉ để đổi cách viết. Repository sở hữu cache và nguồn dữ liệu; view model sở hữu lựa chọn/loading/error của màn hình; QrController sở hữu timer, expiry và retry. SessionCoordinator quyết định mở/đóng/phục hồi phiên, không để UI tự phối hợp nhiều cờ boolean. Command đang chạy vô hiệu hóa đúng nút và ngăn thao tác trùng. Không tạo lớp use-case cho từng getter đơn giản.

## Thứ tự triển khai

1. Theme/component dùng chung + shell gọn; bỏ nhãn phân công và nhận dạng giả. Render component riêng trước khi ghép màn hình.
2. Làm lại chọn lớp/ca, QR và bảng kết quả trên API hiện có; kiểm tra với trạng thái loading/error/expired.
3. Tách QrController và API client/repositories từng bước; giữ facade tương thích trong lúc di chuyển và chạy regression.
4. Bổ sung hợp đồng roster theo lớp, mapping file và nguồn lịch thật rồi mới ghép luồng buổi dạy thống nhất.

## Lựa chọn thư viện và nguồn tham khảo

- Flutter Material hiện có: dùng controls, dialog, navigation và date picker sẵn có, theme lại; không thêm bộ UI ngoài.
- Widget bảng/chip/state của dự án: tái sử dụng và chuẩn hóa thay vì viết một bộ thứ hai.
- DataTable phù hợp roster hiện có 29–37 dòng; nếu mở bảng lịch sử lớn mới đánh giá phân trang/virtualization. [Flutter DataTable](https://api.flutter.dev/flutter/material/DataTable-class.html).
- Tách UI/data và view model/repository theo [Flutter architecture guide](https://docs.flutter.dev/app-architecture/guide).
- Navigation ít mục, thích ứng desktop theo [Flutter NavigationRail](https://api.flutter.dev/flutter/material/NavigationRail-class.html).
- Đưa thông tin phụ vào chi tiết theo [NN/g progressive disclosure](https://www.nngroup.com/articles/progressive-disclosure/).
- Ảnh FAP người dùng cung cấp: tham khảo thao tác chọn buổi → danh sách → QR; không sao chép độ dày bảng hoặc suy ra dữ liệu lịch.

## Nghiệm thu

Kiểm tra Windows release ở 1024×768, 1280×720, 1366×768 và 1920×1080; text scale 125/150%; tên lớp dài; bàn phím/focus; dữ liệu rỗng, stale, offline, lỗi và QR hết hạn. Chuyển tab giữ lựa chọn/cuộn, không tăng request vô cớ. Chạy analyze và regression hiện có; kiểm tra ảnh màn hình thật và luồng thật. Việc nghiệm thu Form → Attendance còn chờ tài khoản thử, được theo dõi độc lập trong qr-recovery-20260925.
