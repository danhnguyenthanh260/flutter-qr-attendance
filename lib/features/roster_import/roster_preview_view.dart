import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/roster_import.dart';
import '../teaching/session_provider.dart';
import 'roster_import_view_model.dart';

class RosterPreviewView extends StatefulWidget {
  const RosterPreviewView({super.key});
  @override
  State<RosterPreviewView> createState() => _RosterPreviewViewState();
}

class _RosterPreviewViewState extends State<RosterPreviewView> {
  final _model = RosterImportViewModel();
  bool _importing = false;
  String? _importResult;
  Future<void> _import(RosterImport document) async {
    final match = RegExp(
      r'^([A-Z0-9-]+)_([A-Z0-9-]+)_.+_(FALL|SUMMER|SPRING)([0-9]{4})_',
    ).firstMatch(document.sourceName);
    if (match == null ||
        document.students.any((s) => s.className != match.group(1))) {
      setState(
        () => _importResult = 'Không xác định được lớp/môn/học kỳ từ tên file. Hãy giữ tên bản xuất gốc.',
      );
      return;
    }
    final className = match.group(1)!;
    final course = match.group(2)!;
    final term = '${match.group(3)}${match.group(4)}';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nhập danh sách vào Google Sheets'),
        content: Text(
          '$className · $course · $term\n${document.students.length} sinh viên.\nTạo lớp riêng, giữ dữ liệu cũ. Không tạo lịch học hoặc kết quả điểm danh. Email từ file sẽ được dùng để đối chiếu tài khoản Google.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Nhập danh sách'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() {
      _importing = true;
      _importResult = null;
    });
    try {
      final count = await context.read<SessionProvider>().importRoster({
        'class_name': className,
        'course_code': course,
        'term': term,
        'students': document.students
            .map(
              (s) => {
                'roll_number': s.rollNumber,
                'email': s.email,
                'member_code': s.memberCode,
                'student_name': s.fullName,
              },
            )
            .toList(),
      });
      if (mounted) {
        setState(
          () => _importResult =
              'Đã nhập $count sinh viên vào lớp $className · $course · $term.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _importResult =
              'Chưa xác nhận nhập thành công: $e. Có thể thử lại cùng file; không tạo bản sao.',
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

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
              'Kiểm tra danh sách trước khi nhập. File này không chứa lịch sử điểm danh hoặc lịch học.',
            ),
            if (document != null && document.isValid)
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: _importing ? null : () => _import(document),
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: Text(
                    _importing ? 'Đang nhập…' : 'Nhập lớp vào Google Sheets',
                  ),
                ),
              ),
            if (_importResult != null) Text(_importResult!),
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
