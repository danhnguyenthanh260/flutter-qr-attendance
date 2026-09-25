import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../data/models/roster_import.dart';

class RosterPreviewView extends StatefulWidget {
  const RosterPreviewView({super.key});
  @override
  State<RosterPreviewView> createState() => _RosterPreviewViewState();
}

class _RosterPreviewViewState extends State<RosterPreviewView> {
  final Map<String, RosterImport> _documents = {};
  String? _selected;
  String _search = '';
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadBundledSources();
  }

  Future<void> _loadBundledSources() async {
    final directory = Directory(
      '${File(Platform.resolvedExecutable).parent.path}${Platform.pathSeparator}roster-sources',
    );
    if (!await directory.exists()) return;
    final files = await directory
        .list()
        .where(
          (item) => item is File && item.path.toLowerCase().endsWith('.xls'),
        )
        .cast<File>()
        .toList();
    files.sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      if (!mounted) return;
      await _read(XFile(file.path));
    }
  }

  Future<void> _read(XFile file) async {
    try {
      if (await file.length() > 5 * 1024 * 1024) {
        throw const FormatException('File vượt giới hạn 5 MB.');
      }
      final bytes = await file.readAsBytes();
      final id = sha256.convert(bytes).toString();
      final result = RosterImport.parse(
        await file.readAsString(),
        sourceName: file.name,
      );
      if (!mounted) return;
      setState(() {
        _documents[id] = result;
        _selected = id;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Không đọc được file. Hãy chọn file Excel XML (.xls) xuất từ danh sách lớp, tối đa 5 MB.',
        );
      }
    }
  }

  Future<void> _pick() async {
    setState(() => _busy = true);
    try {
      final file = await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(
            label: 'Danh sách lớp Excel XML',
            extensions: ['xls', 'xml'],
          ),
        ],
      );
      if (file != null) await _read(file);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Không mở được cửa sổ chọn file. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final document = _documents[_selected];
    final rows =
        document?.students
            .where(
              (s) => '${s.className} ${s.rollNumber} ${s.fullName} ${s.email}'
                  .toLowerCase()
                  .contains(_search.toLowerCase()),
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
                onPressed: _busy ? null : _pick,
                icon: const Icon(Icons.file_open),
                label: const Text('Mở file Excel'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Xem trước trên máy • Chưa nhập vào Google Sheets. File danh sách không chứa lịch sử điểm danh hoặc lịch học.',
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 16),
          if (_documents.isNotEmpty) ...[
            DropdownButton<String>(
              value: _selected,
              isExpanded: true,
              items: _documents.entries
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
              onChanged: (value) => setState(() => _selected = value),
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
              onChanged: (value) => setState(() => _search = value),
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
  }
}
