enum SessionStatus {
  idle,
  active,
  closing,
  closed,
}

class SessionSlot {
  final int slotNumber;
  final String timeRange;
  final String date;

  const SessionSlot({
    required this.slotNumber,
    required this.timeRange,
    required this.date,
  });

  factory SessionSlot.fromJson(Map<String, dynamic> json) {
    return SessionSlot(
      slotNumber: json['slot_number'] as int,
      timeRange: json['time_range'] as String,
      date: json['date'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'slot_number': slotNumber,
      'time_range': timeRange,
      'date': date,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionSlot &&
          runtimeType == other.runtimeType &&
          slotNumber == other.slotNumber &&
          date == other.date;

  @override
  int get hashCode => Object.hash(slotNumber, date);
}

class AttendanceSession {
  final String id;
  final String classId;
  final String className;
  final SessionSlot slot;
  final DateTime openedAt;
  final DateTime? closedAt;
  final SessionStatus status;

  const AttendanceSession({
    required this.id,
    required this.classId,
    required this.className,
    required this.slot,
    required this.openedAt,
    this.closedAt,
    this.status = SessionStatus.active,
  });

  AttendanceSession copyWith({
    String? id,
    String? classId,
    String? className,
    SessionSlot? slot,
    DateTime? openedAt,
    DateTime? closedAt,
    SessionStatus? status,
  }) {
    return AttendanceSession(
      id: id ?? this.id,
      classId: classId ?? this.classId,
      className: className ?? this.className,
      slot: slot ?? this.slot,
      openedAt: openedAt ?? this.openedAt,
      closedAt: closedAt ?? this.closedAt,
      status: status ?? this.status,
    );
  }

  factory AttendanceSession.fromJson(Map<String, dynamic> json) {
    return AttendanceSession(
      id: json['id'] as String,
      classId: json['class_id'] as String,
      className: json['class_name'] as String,
      slot: SessionSlot.fromJson(json['slot'] as Map<String, dynamic>),
      openedAt: DateTime.parse(json['opened_at'] as String),
      closedAt: json['closed_at'] != null
          ? DateTime.parse(json['closed_at'] as String)
          : null,
      status: SessionStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => SessionStatus.active,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'class_id': classId,
      'class_name': className,
      'slot': slot.toJson(),
      'opened_at': openedAt.toIso8601String(),
      'closed_at': closedAt?.toIso8601String(),
      'status': status.name,
    };
  }
}
