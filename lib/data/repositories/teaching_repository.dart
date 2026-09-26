import '../models/teaching_overview.dart';

abstract interface class TeachingRepository {
  Future<int> importRoster(Map<String, dynamic> payload);
  Future<TeachingOverview> getTeachingOverview(String classId);
}
