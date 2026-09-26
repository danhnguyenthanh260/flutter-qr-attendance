import '../models/teaching_overview.dart';

abstract interface class TeachingRepository {
  Future<Map<String, TeachingOverview>> getWeeklyOverview();
  Future<int> importRoster(Map<String, dynamic> payload);
  Future<TeachingOverview> getTeachingOverview(String classId);
}
