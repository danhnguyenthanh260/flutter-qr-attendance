# Chat và báo cáo chuyên cần

## Mục tiêu

Chat và nút Tạo báo cáo dùng chung số liệu xác định theo lớp, buổi hoặc khoảng ngày, kèm nguồn, thời điểm và trạng thái hoàn tất. AI diễn giải số liệu đã tính; không tự tạo người vắng, số buổi vắng, lý do vắng hoặc kết luận gian lận.

## Dữ liệu có và thiếu

Hai file nguồn mới cung cấp 66 dòng roster, không có P/A lịch sử, tổng số buổi hoặc quy chế cấm thi. Có thể làm danh sách lớp, kiểm tra import và mẫu báo cáo có trạng thái thiếu dữ liệu. Chỉ tính chuyên cần khi có Attendance và phiên đã chốt phù hợp; không coi không có lịch sử là 0 buổi vắng.

## Blocker của nhánh AI hiện tại

Nhánh `feat/person-5-issue-18-ai-assistant` tại `f620d14` có giao diện chat/report nhưng chưa vào main. Source `student_absence_warning.dart` dùng `_calculateDeterministicBaseAbsence` băm email để tạo vắng tích lũy, mặc định 20 buổi và coi trạng thái khác present là vắng. Những phép tính này không được dùng cho dữ liệu thật hoặc cảnh báo cấm thi. Đây là phát hiện từ source, chưa phải kiểm thử UI của nhánh.

## Contract thống kê cần thực hiện cùng #17

- Số có mặt: định danh roster được đối chiếu với Attendance hợp lệ, không tăng khi duplicate hoặc trigger retry.
- Số chưa điểm danh: roster chưa có Attendance khi phiên chưa chốt; không đưa vào số vắng đã chốt.
- Số vắng: chỉ xác định khi nguồn đầy đủ và buổi đã chốt theo quy tắc gộp phiên được xác nhận.
- Tỷ lệ: ghi mẫu số, phạm vi lớp/buổi và phiên bản roster; mẫu số 0 hoặc thiếu nguồn phải báo không đủ dữ liệu.
- Payload đề xuất: filters, as_of, data_status, sources, metric_definitions và aggregates; tên field cuối cùng cần thống nhất producer/consumer rồi bổ sung kiểm thử contract.
- Câu hỏi thiếu lớp/ngày cần làm rõ; chat/report cùng snapshot phải trả cùng số liệu. Không ngầm lấy lớp đang hiển thị làm câu trả lời toàn trường.

## Cổng nghiệm thu

- [ ] Xóa dữ liệu vắng tạo từ hash và mọi fallback giả lập trên luồng thật; không tạo cảnh báo khi thiếu lịch sử hoặc quy chế.
- [ ] Kiểm tra active/closing/closed, roster thiếu/rỗng, nhiều phiên cùng buổi, duplicate, nhiều lớp, khoảng ngày và dữ liệu lịch sử chưa đủ.
- [ ] Xác minh phạm vi gửi provider, vị trí giữ key, chi phí/model và quyền giáo viên. Nhánh có tích hợp Gemini không có nghĩa các quyết định dữ liệu đã được duyệt.
- [ ] Không gửi roster/email lên dịch vụ AI để kiểm thử khi chưa có phạm vi dữ liệu được phép; dùng fixture hoặc số liệu tổng hợp được duyệt.
- [ ] Xử lý timeout/quota/provider lỗi và prompt injection; không cấp cho AI quyền ghi điểm danh, đóng phiên hoặc gửi báo cáo đi.
- [ ] Báo cáo chỉ hiển thị con số có thể đối soát, cùng nguồn/as_of, và nêu rõ phần tạm tính. Không mở rộng sang PDF/Excel/email/lịch gửi tự động khi chưa được yêu cầu.

Issue liên quan: #16 (yêu cầu), #17 (thống kê), #18 (dịch vụ AI), #19 (chat), #24 (báo cáo). Việc cập nhật tài liệu không tự đóng hoặc mở lại issue đã có.
