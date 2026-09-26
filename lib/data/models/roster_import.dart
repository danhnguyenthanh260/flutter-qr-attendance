import 'package:xml/xml.dart';

class RosterStudent {
  final String className;
  final String rollNumber;
  final String email;
  final String memberCode;
  final String fullName;
  const RosterStudent(
    this.className,
    this.rollNumber,
    this.email,
    this.memberCode,
    this.fullName,
  );
  String get emailKey => email.trim().toLowerCase();
}

class RosterImport {
  final String sourceName;
  final List<RosterStudent> students;
  final List<String> errors;
  const RosterImport(this.sourceName, this.students, this.errors);
  bool get isValid => errors.isEmpty;

  static RosterImport parse(String xml, {required String sourceName}) {
    const ns = 'urn:schemas-microsoft-com:office:spreadsheet';
    final document = XmlDocument.parse(xml);
    if (document.rootElement.name.local != 'Workbook' ||
        document.rootElement.namespaceUri != ns) {
      throw const FormatException(
        'File cần là Excel XML SpreadsheetML (.xls).',
      );
    }
    final students = <RosterStudent>[];
    final errors = <String>[];
    final rolls = <String>{};
    final emails = <String>{};
    for (final sheet in document.findAllElements(
      'Worksheet',
      namespaceUri: ns,
    )) {
      final rows = sheet.findAllElements('Row', namespaceUri: ns).toList();
      if (rows.isEmpty) continue;
      List<String> cells(XmlElement row) {
        final result = <String>[];
        for (final cell in row.findElements('Cell', namespaceUri: ns)) {
          final rawIndex = cell.getAttribute('Index', namespaceUri: ns);
          final index = rawIndex == null
              ? result.length + 1
              : int.tryParse(rawIndex);
          if (index == null || index <= result.length || index > 512) {
            throw const FormatException('Chỉ số cột trong file không hợp lệ.');
          }
          while (result.length < index - 1) {
            result.add('');
          }
          final data = cell.findElements('Data', namespaceUri: ns).firstOrNull;
          result.add(data?.innerText.trim() ?? '');
        }
        return result;
      }

      final header = cells(rows.first);
      const required = [
        'Class',
        'RollNumber',
        'Email',
        'MemberCode',
        'FullName',
      ];
      if (required.any(
        (name) => header.where((value) => value == name).length != 1,
      )) {
        errors.add(
          'Trang ${sheet.getAttribute('Name', namespaceUri: ns) ?? ''}: thiếu hoặc trùng cột bắt buộc.',
        );
        continue;
      }
      for (var i = 1; i < rows.length; i++) {
        final values = cells(rows[i]);
        if (values.every((value) => value.isEmpty)) continue;
        String field(String name) {
          final index = header.indexOf(name);
          return index < values.length ? values[index] : '';
        }

        final student = RosterStudent(
          field('Class'),
          field('RollNumber'),
          field('Email'),
          field('MemberCode'),
          field('FullName'),
        );
        if ([
          student.className,
          student.rollNumber,
          student.email,
          student.fullName,
        ].any((v) => v.isEmpty)) {
          errors.add('Dòng ${i + 1}: thiếu lớp, MSSV, email hoặc họ tên.');
        }
        if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(student.email)) {
          errors.add('Dòng ${i + 1}: email không hợp lệ.');
        }
        if (!rolls.add(
          '${student.className}|${student.rollNumber.toLowerCase()}',
        )) {
          errors.add('Dòng ${i + 1}: trùng MSSV trong cùng lớp.');
        }
        if (!emails.add('${student.className}|${student.emailKey}')) {
          errors.add('Dòng ${i + 1}: trùng email trong cùng lớp.');
        }
        students.add(student);
      }
    }
    if (students.isEmpty) errors.add('Không có sinh viên trong file.');
    return RosterImport(
      sourceName,
      List.unmodifiable(students),
      List.unmodifiable(errors),
    );
  }
}
