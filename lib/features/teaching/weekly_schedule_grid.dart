import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/models/class_model.dart';
import '../../data/models/session_model.dart';
import '../../data/models/teaching_overview.dart';

class CalendarLesson {
  const CalendarLesson(this.classModel, this.slot, this.data);
  final ClassModel classModel;
  final SessionSlot slot;
  final TeachingOverview? data;
}

class WeeklyScheduleGrid extends StatelessWidget {
  const WeeklyScheduleGrid({
    super.key,
    required this.week,
    required this.lessons,
    required this.onOpen,
  });
  final DateTime week;
  final List<CalendarLesson> lessons;
  final ValueChanged<CalendarLesson> onOpen;
  @override
  Widget build(BuildContext context) {
    final days = List.generate(7, (i) => week.add(Duration(days: i)));
    final numbers = {
      ...List.generate(6, (i) => i + 1),
      ...lessons.map((l) => l.slot.slotNumber),
    }.toList()..sort();
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: constraints.maxWidth < 900 ? 900 : constraints.maxWidth,
          child: Table(
            border: TableBorder.all(color: Theme.of(context).dividerColor),
            columnWidths: const {0: FixedColumnWidth(52)},
            defaultVerticalAlignment: TableCellVerticalAlignment.top,
            children: [
              TableRow(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                ),
                children: [
                  const Padding(padding: EdgeInsets.all(12), child: Text('Ca')),
                  for (var i = 0; i < 7; i++)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        '${const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'][i]}\n${DateFormat('dd/MM').format(days[i])}',
                      ),
                    ),
                ],
              ),
              for (final number in numbers)
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text('$number'),
                    ),
                    for (final day in days)
                      ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 60),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final lesson in lessons.where(
                              (l) =>
                                  l.slot.slotNumber == number &&
                                  l.slot.date ==
                                      DateFormat('yyyy-MM-dd').format(day),
                            ))
                              _lesson(context, lesson),
                          ],
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _lesson(BuildContext context, CalendarLesson lesson) {
    final sessions =
        lesson.data?.sessionsFor(lesson.slot) ?? <AttendanceSession>[];
    final status = sessions.any((s) => s.status == SessionStatus.active)
        ? 'Đang điểm danh'
        : sessions.any((s) => s.status == SessionStatus.closing)
        ? 'Đang đóng'
        : sessions.isEmpty
        ? 'Chưa điểm danh'
        : 'Đã đóng';
    return Padding(
      padding: const EdgeInsets.all(3),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          key: ValueKey(
            'lesson:${lesson.classModel.id}:${lesson.slot.date}:${lesson.slot.slotNumber}',
          ),
          onTap: () => onOpen(lesson),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${lesson.classModel.name} · ${lesson.classModel.courseCode}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(lesson.slot.timeRange),
                if (lesson.classModel.room.isNotEmpty)
                  Text('Phòng ${lesson.classModel.room}'),
                Text(
                  lesson.data == null
                      ? 'Chưa tải danh sách sinh viên'
                      : '${lesson.data!.present(lesson.slot)}/${lesson.data!.roster.length} đã điểm danh',
                ),
                Text(lesson.data == null ? 'Lịch lưu tạm' : status),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
