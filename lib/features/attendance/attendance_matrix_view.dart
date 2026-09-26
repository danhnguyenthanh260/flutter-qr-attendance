import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../teaching/session_provider.dart';

class AttendanceMatrixView extends StatefulWidget {
  const AttendanceMatrixView({super.key});
  @override
  State<AttendanceMatrixView> createState() => _AttendanceMatrixViewState();
}

class _AttendanceMatrixViewState extends State<AttendanceMatrixView> {
  String? _classId;
  bool _busy = false;
  String? _error;
  Future<void> _refresh() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<SessionProvider>().refreshTeachingWorkspace();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SessionProvider>();
    final classes = provider.classes;
    final id = classes.any((c) => c.id == _classId)
        ? _classId
        : classes.firstOrNull?.id;
    final data = provider.workspaceOverview?[id];
    final slots =
        {
          for (final slot in [
            ...?data?.slots,
            ...?data?.sessions.map((s) => s.slot),
          ])
            '${slot.date}:${slot.slotNumber}': slot,
        }.values.toList()..sort(
          (a, b) =>
              '${a.date}-${a.slotNumber.toString().padLeft(2, '0')}'.compareTo(
                '${b.date}-${b.slotNumber.toString().padLeft(2, '0')}',
              ),
        );
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DropdownButton<String>(
                value: id,
                hint: const Text('Chọn lớp'),
                items: classes
                    .map(
                      (c) => DropdownMenuItem(
                        value: c.id,
                        child: Text('${c.name} · ${c.courseCode}'),
                      ),
                    )
                    .toList(),
                onChanged: _busy ? null : (v) => setState(() => _classId = v),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Cập nhật dữ liệu'),
              ),
            ],
          ),
          const Text(
            'P: có mặt · A: vắng · …: chưa chốt · —: chưa mở · ∅: không thuộc roster phiên · ?: phiên cũ thiếu roster gốc',
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
          Expanded(
            child: data == null || slots.isEmpty
                ? const Center(
                    child: Text(
                      'Chưa có lịch. Bấm Cập nhật dữ liệu để tải từ Sheet.',
                    ),
                  )
                : SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStatePropertyAll(
                          Theme.of(context).colorScheme.primaryContainer,
                        ),
                        columns: [
                          const DataColumn(label: Text('MSSV')),
                          const DataColumn(label: Text('Họ tên')),
                          for (final slot in slots)
                            DataColumn(
                              label: Text(
                                '${slot.date}\nCa ${slot.slotNumber}',
                              ),
                            ),
                        ],
                        rows: [
                          for (final student in data.historicalRoster)
                            DataRow(
                              cells: [
                                DataCell(Text(student.rollNumber)),
                                DataCell(Text(student.displayName)),
                                for (final slot in slots)
                                  DataCell(Text(data.status(student, slot))),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
