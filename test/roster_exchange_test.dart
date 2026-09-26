import 'package:flutter_qr_attendance/data/models/attendance_result_model.dart';
import 'package:flutter_qr_attendance/data/models/roster_exchange.dart';
import 'package:flutter_qr_attendance/data/models/roster_import.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const student = RosterEntry(
    id: 'stable',
    classId: 'c',
    rollNumber: 'SE000001',
    email: 'one@example.edu',
    emailKey: 'one@example.edu',
    studentName: 'Nguyễn An & Bảo',
    memberCode: 'Member01',
    isActive: false,
  );
  test('Excel XML round trip preserves Vietnamese, IDs and inactive state', () {
    final xml = rosterXml('SE1913', [student]);
    final parsed = RosterImport.parse(xml, sourceName: 'export.xls');
    expect(parsed.errors, isEmpty);
    expect(parsed.students.single.fullName, student.displayName);
    expect(
      previewRosterImport(xml, 'export.xls', 'SE1913', [student]),
      isEmpty,
    );
    final added = previewRosterImport(xml, 'export.xls', 'SE1913', []).single;
    expect(added['is_active'], false);
    expect(added['roll_number'], 'SE000001');
  });
  test('import updates by MSSV without deleting omitted students', () {
    final xml = rosterXml('SE1913', [
      student,
    ]).replaceAll('one@example.edu', 'new@example.edu');
    final changes = previewRosterImport(xml, 'arbitrary-name.xls', 'SE1913', [
      student,
      const RosterEntry(
        id: 'other',
        classId: 'c',
        rollNumber: 'SE000002',
        email: 'two@example.edu',
        emailKey: 'two@example.edu',
      ),
    ]);
    expect(changes.length, 1);
    expect(changes.single['id'], 'stable');
    expect(changes.single['email'], 'new@example.edu');
  });
  test('wrong class and invalid Active fail before a write', () {
    final xml = rosterXml('SE1913', [student]);
    expect(
      () => previewRosterImport(xml, 'x.xls', 'SE1919', []),
      throwsFormatException,
    );
    expect(
      () => previewRosterImport(
        xml.replaceAll('>false<', '>maybe<'),
        'x.xls',
        'SE1913',
        [],
      ),
      throwsFormatException,
    );
  });
}
