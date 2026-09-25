import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/models/roster_import.dart';
import 'roster_import_view_model.dart';

class RosterPreviewView extends StatefulWidget {
  const RosterPreviewView({super.key});
  @override
  State<RosterPreviewView> createState() => _RosterPreviewViewState();
}

class _RosterPreviewViewState extends State<RosterPreviewView> {
  final _model = RosterImportViewModel();
  @override
  void initState() {
    super.initState();
    unawaited(_model.loadBundledSources());
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _model,
    builder: (context, _) {
      final document = _model.documents[_model.selected];
      final rows =
          document?.students
              .where(
                (s) => '${s.className} ${s.rollNumber} ${s.fullName} ${s.email}'
                    .toLowerCase()
                    .contains(_model.search.toLowerCase()),
              )
              .toList() ??
          <RosterStudent>[];
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Danh sách lớp',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                FilledButton.icon(
                  onPressed: _model.busy ? null : _model.pick,
                  icon: const Icon(Icons.file_open),
                  label: const Text('Mở file Excel'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Xem trước trên máy • Chưa nhập vào Google Sheets. File danh sách không chứa lịch sử điểm danh hoặc lịch học.',
            ),
            if (_model.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _model.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 16),
            if (_model.documents.isNotEmpty) ...[
              DropdownButton<String>(
                value: _model.selected,
                isExpanded: true,
                items: _model.documents.entries
                    .map(
                      (e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(
                          e.value.sourceName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _model.select,
              ),
              Text(
                '${document!.students.length} sinh viên • ${document.errors.isEmpty ? 'Không phát hiện lỗi định danh' : '${document.errors.length} lỗi cần kiểm tra'}',
              ),
              if (document.errors.isNotEmpty)
                SizedBox(
                  height: 70,
                  child: ListView(
                    children: document.errors
                        .map(
                          (error) => Text(
                            error,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              const SizedBox(height: 8),
              TextField(
                onChanged: _model.filter,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Tìm MSSV, tên hoặc email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Lớp')),
                        DataColumn(label: Text('MSSV')),
                        DataColumn(label: Text('Họ tên')),
                        DataColumn(label: Text('Email')),
                      ],
                      rows: rows
                          .map(
                            (student) => DataRow(
                              cells: [
                                DataCell(Text(student.className)),
                                DataCell(Text(student.rollNumber)),
                                DataCell(Text(student.fullName)),
                                DataCell(Text(student.email)),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ),
            ] else
              const Expanded(
                child: Center(
                  child: Text(
                    'Mở file danh sách lớp để kiểm tra dữ liệu.\nThông tin được xử lý trên máy, không gửi tới AI.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}
