class ClassModel {
  final String id;
  final String name;
  final String courseCode;
  final String room;
  final int totalStudents;
  final String scheduleDescription;
  final int totalSlots;

  const ClassModel({
    required this.id,
    required this.name,
    required this.courseCode,
    required this.room,
    required this.totalStudents,
    required this.scheduleDescription,
    this.totalSlots = 20,
  });

  factory ClassModel.fromJson(Map<String, dynamic> json) {
    return ClassModel(
      id: json['id'] as String,
      name: json['name'] as String,
      courseCode: json['course_code'] as String,
      room: json['room'] as String,
      totalStudents: json['total_students'] as int,
      scheduleDescription: json['schedule_description'] as String,
      totalSlots: (json['total_slots'] as num?)?.toInt() ?? 20,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'course_code': courseCode,
      'room': room,
      'total_students': totalStudents,
      'schedule_description': scheduleDescription,
      'total_slots': totalSlots,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClassModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
