import '../models/class_model.dart';
import '../models/teaching_overview.dart';

abstract interface class TeachingRepository {
  Future<Map<String, TeachingOverview>> getWeeklyOverview();
  Future<int> importRoster(Map<String, dynamic> payload);
  Future<TeachingOverview> getTeachingOverview(String classId);
}

abstract interface class ScheduleSnapshotSource {
  Future<
    ({
      DateTime saved,
      List<ClassModel> classes,
      Map<String, TeachingOverview> data,
    })?
  >
  readScheduleSnapshot();
}
