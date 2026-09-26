import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/attendance_result_model.dart';
import '../../data/models/class_roster.dart';
import '../../data/models/roster_exchange.dart';
import '../teaching/session_provider.dart';
import 'roster_preview_view.dart';
import 'student_editor.dart';

class ClassDataView extends StatefulWidget {
  const ClassDataView({super.key});
  @override
  State<ClassDataView> createState() => _ClassDataViewState();
}

class _ClassDataViewState extends State<ClassDataView> {
  String? _id;
  ClassRoster? _roster;
  bool _busy = false;
  bool _inactive = false;
  String _query = '';
  String? _message;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load(refreshWorkspace: false);
    });
  }

  Future<void> _load({String? id, bool refreshWorkspace = true}) async {
    if (_busy) return;
    final provider = context.read<SessionProvider>();
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (refreshWorkspace || provider.workspaceOverview == null) {
        await provider.refreshTeachingWorkspace();
      }
      final selected = id ?? _id ?? provider.classes.firstOrNull?.id;
      final valid = provider.classes.any((c) => c.id == selected)
          ? selected
          : provider.classes.firstOrNull?.id;
      if (mounted && valid != _id) {
        setState(() {
          _id = valid;
          _roster = null;
        });
      }
      final roster = valid == null
          ? null
          : await provider.getClassRoster(valid);
      if (mounted) {
        setState(() {
          _id = valid;
          _roster = roster;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _message = 'Không tải được danh sách: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export(bool template) async {
    final cls = context
        .read<SessionProvider>()
        .classes
        .where((c) => c.id == _id)
        .firstOrNull;
    if (cls == null) return;
    try {
      final location = await getSaveLocation(
        suggestedName: '${cls.name}_${template ? 'mau' : 'roster'}.xls',
        acceptedTypeGroups: [
          const XTypeGroup(label: 'Excel XML', extensions: ['xls']),
        ],
      );
      if (location == null) return;
      final bytes = Uint8List.fromList(
        utf8.encode(rosterXml(cls.name, template ? [] : _roster!.students)),
      );
      await XFile.fromData(
        bytes,
        mimeType: 'application/vnd.ms-excel',
      ).saveTo(location.path);
      if (mounted) {
        setState(
          () => _message =
              'Đã xuất ${template ? 'mẫu trống' : 'toàn bộ danh sách, gồm cả sinh viên ngừng học'}: ${location.path}',
        );
      }
    } catch (e) {
      if (mounted) setState(() => _message = 'Không xuất được file: $e');
    }
  }

  Future<void> _import() async {
    final cls = context.read<SessionProvider>().classes.firstWhere(
      (c) => c.id == _id,
    );
    try {
      final file = await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(
            label: 'Excel XML SpreadsheetML',
            extensions: ['xls', 'xml'],
          ),
        ],
      );
      if (file == null || !mounted) return;
      if (await file.length() > 5 * 1024 * 1024) {
        throw const FormatException('File vượt 5 MB.');
      }
      final changes = previewRosterImport(
        await file.readAsString(),
        file.name,
        cls.name,
        _roster!.students,
      );
      if (mounted) await _confirm(changes);
    } catch (e) {
      if (mounted) setState(() => _message = 'Không nhập được file: $e');
    }
  }

  Future<void> _edit([RosterEntry? student]) async {
    final change = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => StudentEditor(student: student),
    );
    if (change != null && mounted) await _confirm([change]);
  }

  Future<void> _confirm(List<Map<String, dynamic>> changes) async {
    if (changes.isEmpty) {
      setState(() => _message = 'File không có thay đổi.');
      return;
    }
    final baseline = _roster!;
    final id = _id!;
    final existing = {for (final s in baseline.students) s.id: s};
    final merged = {...existing};
    for (final row in changes) {
      merged[row['id'] == ''
          ? 'new:${row['roll_number']}'
          : row['id'] as String] = RosterEntry.fromJson(
        row,
      );
    }
    final emails = <String>{}, rolls = <String>{};
    for (final s in merged.values) {
      if (!emails.add(s.emailKey) ||
          (s.rollNumber.isNotEmpty && !rolls.add(s.rollNumber.toUpperCase()))) {
        setState(
          () => _message = 'MSSV hoặc email trùng trong lớp (kể cả người ngừng học). Sửa file hoặc sinh viên hiện có.',
        );
        return;
      }
    }
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('Xem trước ${changes.length} thay đổi'),
        content: SizedBox(
          width: 750,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chỉ cập nhật các dòng dưới đây. Sinh viên không có trong file được giữ nguyên. Không xóa lịch sử điểm danh.',
                ),
                if (baseline.legacySessions > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Lưu ý: ${baseline.legacySessions} phiên cũ chưa có roster gốc. Khi lưu, danh sách hiện tại sẽ được giữ làm mốc cho các phiên đó; không thể khôi phục chính xác roster tại thời điểm mở phiên cũ.',
                    ),
                  ),
                for (final row in changes)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(_describeChange(row, existing[row['id']])),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Xác nhận lưu'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    final provider = context.read<SessionProvider>();
    setState(() => _busy = true);
    try {
      final saved = await provider.updateRoster({
        'class_id': id,
        'revision': baseline.revision,
        'accept_legacy_snapshot': baseline.legacySessions > 0,
        'students': changes,
      });
      if (!mounted) return;
      setState(() {
        _roster = saved;
        _message = 'Đã lưu ${changes.length} thay đổi lên Sheet.';
      });
      try {
        await provider.refreshTeachingWorkspace();
      } catch (_) {
        if (mounted) {
          setState(
            () => _message = 'Đã lưu lên Sheet; chưa tải lại được lịch. Bấm Làm mới để đồng bộ.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _message =
              'Chưa xác nhận lưu: $e. Hãy tải lại danh sách trước khi thử tiếp.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _describeChange(Map<String, dynamic> row, RosterEntry? old) {
    final title = '${row['roll_number']} · ${row['student_name']}';
    if (old == null) {
      return 'THÊM · $title\n${row['email']} · ${row['is_active'] == true ? 'Đang học' : 'Ngừng học'}';
    }
    final labels = {
      'roll_number': 'MSSV',
      'student_name': 'Họ tên',
      'email': 'Email',
      'member_code': 'MemberCode',
      'is_active': 'Đang học',
    };
    final before = old.toJson();
    return 'SỬA · $title\n${labels.entries.where((e) => before[e.key] != row[e.key]).map((e) => '${e.value}: ${before[e.key]} → ${row[e.key]}').join('\n')}';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SessionProvider>();
    final id = provider.classes.any((c) => c.id == _id) ? _id : null;
    final ready = !_busy && _roster != null && id != null;
    final editing = ready && provider.activeSession?.classId != id;
    final students =
        _roster?.students
            .where(
              (s) =>
                  (_inactive || s.isActive) &&
                  '${s.rollNumber} ${s.displayName} ${s.email}'
                      .toLowerCase()
                      .contains(_query),
            )
            .toList() ??
        [];
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DropdownButton<String>(
                value: id,
                hint: const Text('Chọn lớp'),
                items: provider.classes
                    .map(
                      (c) => DropdownMenuItem(
                        value: c.id,
                        child: Text('${c.name} · ${c.courseCode}'),
                      ),
                    )
                    .toList(),
                onChanged: _busy
                    ? null
                    : (v) => _load(id: v, refreshWorkspace: false),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Làm mới'),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => Scaffold(
                              appBar: AppBar(title: const Text('Nhập lớp mới')),
                              body: const SafeArea(child: RosterPreviewView()),
                            ),
                          ),
                        );
                        if (mounted) await _load();
                      },
                child: const Text('Nhập lớp mới từ file FAP'),
              ),
            ],
          ),
          const Text(
            'Danh sách hiện tại trên Sheet. Mẫu là Excel XML (.xls): giữ tên cột, điền Class đúng lớp; Active = true/false. Xuất danh sách để sửa rồi nhập lại.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: ready ? () => _export(true) : null,
                icon: const Icon(Icons.download),
                label: const Text('Tải mẫu'),
              ),
              OutlinedButton.icon(
                onPressed: ready ? () => _export(false) : null,
                icon: const Icon(Icons.file_download),
                label: const Text('Xuất danh sách'),
              ),
              OutlinedButton.icon(
                onPressed: editing ? _import : null,
                icon: const Icon(Icons.upload_file),
                label: const Text('Nhập cập nhật'),
              ),
              FilledButton.icon(
                onPressed: editing ? () => _edit() : null,
                icon: const Icon(Icons.person_add),
                label: const Text('Thêm sinh viên'),
              ),
            ],
          ),
          if (ready && !editing)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Lớp đang có phiên điểm danh. Đóng phiên và chờ chốt xong trước khi sửa danh sách. Vẫn có thể tải mẫu và xuất file.',
              ),
            ),
          if (_busy) const LinearProgressIndicator(),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SelectableText(_message!),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Tìm MSSV, tên, email',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) =>
                      setState(() => _query = v.trim().toLowerCase()),
                ),
              ),
              const SizedBox(width: 12),
              Checkbox(
                value: _inactive,
                onChanged: (v) => setState(() => _inactive = v!),
              ),
              const Text('Hiện ngừng học'),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '${_roster?.students.where((s) => s.isActive).length ?? 0} đang học · ${students.length} hiển thị',
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('MSSV')),
                    DataColumn(label: Text('Họ tên')),
                    DataColumn(label: Text('Email gửi Form')),
                    DataColumn(label: Text('Trạng thái')),
                    DataColumn(label: Text('Thao tác')),
                  ],
                  rows: [
                    for (final s in students)
                      DataRow(
                        cells: [
                          DataCell(Text(s.rollNumber)),
                          DataCell(Text(s.displayName)),
                          DataCell(Text(s.email)),
                          DataCell(Text(s.isActive ? 'Đang học' : 'Ngừng học')),
                          DataCell(
                            Row(
                              children: [
                                IconButton(
                                  tooltip: 'Sửa',
                                  onPressed: editing ? () => _edit(s) : null,
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                TextButton(
                                  onPressed: editing
                                      ? () => _confirm([
                                          {
                                            ...s.toJson(),
                                            'is_active': !s.isActive,
                                          },
                                        ])
                                      : null,
                                  child: Text(
                                    s.isActive ? 'Ngừng học' : 'Khôi phục',
                                  ),
                                ),
                              ],
                            ),
                          ),
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
