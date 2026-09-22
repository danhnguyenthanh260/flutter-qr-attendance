import '../../data/models/attendance_summary.dart';
import '../../data/models/session_model.dart';

class AttendanceLabels {
  const AttendanceLabels._();

  static const Map<String, String> _attemptTypes = {
    'duplicate_email': 'Nộp lại sau khi đã điểm danh',
    'grant_replayed': 'Mở lại liên kết đã dùng',
    'grant_expired': 'Vé QR đã hết hạn',
    'session_closed': 'Phiên đã ngừng nhận',
    'roster_mismatch': 'Email ngoài danh sách lớp',
  };

  static const Map<String, String> _attemptReasons = {
    'duplicate_email': 'Email này đã có lượt điểm danh hợp lệ',
    'form_response_replayed': 'Phản hồi Forms được xử lý lại',
    'grace_expired': 'Quá hạn grace period của vé',
    'session_not_accepting_submissions': 'Phiên không còn nhận lượt nộp',
    'email_not_in_roster': 'Email không có trong roster lớp',
    'grant_already_used': 'Liên kết điểm danh đã được dùng',
  };

  static String studentStatus(StudentAttendanceStatus status) {
    switch (status) {
      case StudentAttendanceStatus.present:
        return 'Có mặt';
      case StudentAttendanceStatus.notYet:
        return 'Chưa điểm danh';
      case StudentAttendanceStatus.absent:
        return 'Vắng';
    }
  }

  static String sessionStatus(SessionStatus status) {
    switch (status) {
      case SessionStatus.idle:
        return 'Chưa mở';
      case SessionStatus.active:
        return 'Đang mở';
      case SessionStatus.closing:
        return 'Đang chốt sổ';
      case SessionStatus.closed:
        return 'Đã chốt';
    }
  }

  static String attemptType(String attemptType) =>
      _attemptTypes[attemptType] ?? attemptType;

  static String? attemptReason(String? reason) {
    if (reason == null || reason.isEmpty) return null;
    return _attemptReasons[reason] ?? reason;
  }
}
