import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_qr_attendance/data/models/roster_import.dart';

String workbook(String rows) =>
    '''<ss:Workbook xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet"><ss:Worksheet ss:Name="Roster"><ss:Table>
<ss:Row>${['Class', 'RollNumber', 'Email', 'MemberCode', 'FullName'].map((v) => '<ss:Cell><ss:Data ss:Type="String">$v</ss:Data></ss:Cell>').join()}</ss:Row>
$rows</ss:Table></ss:Worksheet></ss:Workbook>''';

const row =
    '<ss:Row><ss:Cell><ss:Data>SE_TEST</ss:Data></ss:Cell><ss:Cell><ss:Data>000123</ss:Data></ss:Cell><ss:Cell><ss:Data>Student@example.org</ss:Data></ss:Cell><ss:Cell ss:Index="5"><ss:Data>Nguyễn &amp; An</ss:Data></ss:Cell></ss:Row>';

void main() {
  test('preserves identifiers and Unicode, respects sparse ss:Index', () {
    final result = RosterImport.parse(workbook(row), sourceName: 'test.xls');
    expect(result.errors, isEmpty);
    expect(result.students.single.rollNumber, '000123');
    expect(result.students.single.memberCode, '');
    expect(result.students.single.fullName, 'Nguyễn & An');
    expect(result.students.single.emailKey, 'student@example.org');
  });
  test('reports duplicates without silently dropping rows', () {
    final result = RosterImport.parse(
      workbook('$row$row'),
      sourceName: 'test.xls',
    );
    expect(result.students, hasLength(2));
    expect(result.errors, hasLength(2));
  });
  test('rejects unrelated or broken input', () {
    expect(
      () => RosterImport.parse('<html/>', sourceName: 'test.xls'),
      throwsFormatException,
    );
    final result = RosterImport.parse(
      workbook(row).replaceAll('RollNumber', 'WrongColumn'),
      sourceName: 'test.xls',
    );
    expect(result.isValid, isFalse);
    expect(result.students, isEmpty);
  });
  test('reports missing email instead of shifting sparse cells', () {
    final result = RosterImport.parse(
      workbook(row.replaceAll('Student@example.org', '')),
      sourceName: 'test.xls',
    );
    expect(result.isValid, isFalse);
    expect(result.students.single.fullName, 'Nguyễn & An');
  });
}
