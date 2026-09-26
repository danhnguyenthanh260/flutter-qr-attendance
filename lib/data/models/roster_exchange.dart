import 'package:xml/xml.dart';

import 'attendance_result_model.dart';
import 'roster_import.dart';

/// Excel XML uses explicit String cells: preserves IDs and never emits formulas.
String rosterXml(String className, List<RosterEntry> students) {
  final builder = XmlBuilder();
  builder.processing('xml', 'version="1.0" encoding="UTF-8"');
  builder.element(
    'Workbook',
    attributes: {
      'xmlns': 'urn:schemas-microsoft-com:office:spreadsheet',
      'xmlns:ss': 'urn:schemas-microsoft-com:office:spreadsheet',
    },
    nest: () {
      builder.element(
        'Worksheet',
        attributes: {'ss:Name': 'Roster'},
        nest: () {
          builder.element(
            'Table',
            nest: () {
              for (final row in [
                [
                  'Class',
                  'RollNumber',
                  'Email',
                  'MemberCode',
                  'FullName',
                  'Active',
                ],
                for (final s in students)
                  [
                    className,
                    s.rollNumber,
                    s.email,
                    s.memberCode,
                    s.displayName,
                    s.isActive.toString(),
                  ],
              ]) {
                builder.element(
                  'Row',
                  nest: () {
                    for (final value in row) {
                      builder.element(
                        'Cell',
                        nest: () => builder.element(
                          'Data',
                          attributes: {'ss:Type': 'String'},
                          nest: value,
                        ),
                      );
                    }
                  },
                );
              }
            },
          );
        },
      );
    },
  );
  return builder.buildDocument().toXmlString(pretty: true);
}

List<Map<String, dynamic>> previewRosterImport(
  String source,
  String fileName,
  String className,
  List<RosterEntry> current,
) {
  final parsed = RosterImport.parse(source, sourceName: fileName);
  if (!parsed.isValid) throw FormatException(parsed.errors.join('\n'));
  final document = XmlDocument.parse(source);
  const ns = 'urn:schemas-microsoft-com:office:spreadsheet';
  // Active is optional in original FAP exports; preserve existing status then.
  final statuses = <String, bool>{};
  for (final sheet in document.findAllElements('Worksheet', namespaceUri: ns)) {
    final rows = sheet.findAllElements('Row', namespaceUri: ns).toList();
    List<String> values(XmlElement row) {
      final out = <String>[];
      for (final cell in row.findElements('Cell', namespaceUri: ns)) {
        final index =
            int.tryParse(cell.getAttribute('Index', namespaceUri: ns) ?? '') ??
            out.length + 1;
        while (out.length < index - 1) {
          out.add('');
        }
        out.add(cell.innerText.trim());
      }
      return out;
    }

    if (rows.isEmpty) continue;
    final header = values(rows.first);
    final active = header.indexOf('Active'),
        roll = header.indexOf('RollNumber');
    if (active < 0 || roll < 0) continue;
    for (final row in rows.skip(1)) {
      final cells = values(row);
      if (cells.every((v) => v.isEmpty)) continue;
      if (cells.length <= active ||
          !['true', 'false'].contains(cells[active].toLowerCase())) {
        throw const FormatException('Active cần là true hoặc false.');
      }
      statuses[cells[roll].toUpperCase()] =
          cells[active].toLowerCase() == 'true';
    }
  }
  final changes = <Map<String, dynamic>>[];
  for (final s in parsed.students) {
    if (s.className.trim().toUpperCase() != className.trim().toUpperCase()) {
      throw FormatException(
        'File có lớp ${s.className}; đang chọn $className.',
      );
    }
    final roll = s.rollNumber.toUpperCase();
    final old = current
        .where((r) => r.rollNumber.toUpperCase() == roll)
        .firstOrNull;
    final next = <String, dynamic>{
      'id': old?.id ?? '',
      'roll_number': roll,
      'email': s.emailKey,
      'member_code': s.memberCode,
      'student_name': s.fullName,
      'is_active': statuses[roll] ?? old?.isActive ?? true,
    };
    if (old == null ||
        next.entries.any((e) => e.value != old.toJson()[e.key])) {
      changes.add(next);
    }
  }
  return changes;
}
