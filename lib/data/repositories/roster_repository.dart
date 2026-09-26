import '../models/class_roster.dart';

abstract interface class RosterRepository {
  Future<ClassRoster> getClassRoster(String classId);
  Future<ClassRoster> updateRoster(Map<String, dynamic> payload);
}
