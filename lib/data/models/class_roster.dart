import 'attendance_result_model.dart';

class ClassRoster {
  const ClassRoster(this.students, this.revision, this.legacySessions);
  final List<RosterEntry> students;
  final String revision;
  final int legacySessions;
  factory ClassRoster.fromJson(Map<String, dynamic> json) => ClassRoster(
    (json['students'] as List)
        .map((s) => RosterEntry.fromJson(Map<String, dynamic>.from(s as Map)))
        .toList(),
    json['revision'] as String,
    json['legacy_sessions'] as int,
  );
}
