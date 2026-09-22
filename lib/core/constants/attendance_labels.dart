import '../../data/models/attendance_summary.dart';
import '../../data/models/session_model.dart';

class AttendanceLabels {
  const AttendanceLabels._();

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
}
