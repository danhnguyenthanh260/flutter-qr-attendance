import 'package:flutter/material.dart';

import '../../data/models/attendance_result_model.dart';

class StudentEditor extends StatefulWidget {
  const StudentEditor({super.key, this.student});
  final RosterEntry? student;
  @override
  State<StudentEditor> createState() => _StudentEditorState();
}

class _StudentEditorState extends State<StudentEditor> {
  final _form = GlobalKey<FormState>();
  late final _roll = TextEditingController(text: widget.student?.rollNumber);
  late final _name = TextEditingController(text: widget.student?.studentName);
  late final _email = TextEditingController(text: widget.student?.email);
  late final _member = TextEditingController(text: widget.student?.memberCode);
  @override
  void dispose() {
    for (final c in [_roll, _name, _email, _member]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.student == null ? 'Thêm sinh viên' : 'Sửa sinh viên'),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _roll,
                decoration: const InputDecoration(labelText: 'MSSV'),
                validator: (v) =>
                    RegExp(r'^[A-Za-z0-9-]{2,32}$').hasMatch(v?.trim() ?? '')
                    ? null
                    : 'MSSV gồm 2–32 chữ, số hoặc dấu -',
              ),
              TextFormField(
                controller: _name,
                maxLength: 200,
                decoration: const InputDecoration(labelText: 'Họ tên'),
                validator: (v) =>
                    (v?.trim().isNotEmpty ?? false) ? null : 'Nhập họ tên',
              ),
              TextFormField(
                controller: _email,
                maxLength: 254,
                decoration: const InputDecoration(labelText: 'Email gửi Form'),
                validator: (v) =>
                    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                        .hasMatch(v?.trim() ?? '')
                    ? null
                    : 'Email không hợp lệ',
              ),
              TextFormField(
                controller: _member,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'MemberCode (không bắt buộc)',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: () {
          if (!_form.currentState!.validate()) return;
          Navigator.pop(context, <String, dynamic>{
            'id': widget.student?.id ?? '',
            'roll_number': _roll.text.trim().toUpperCase(),
            'email': _email.text.trim().toLowerCase(),
            'student_name': _name.text.trim(),
            'member_code': _member.text.trim(),
            'is_active': widget.student?.isActive ?? true,
          });
        },
        child: const Text('Xem trước'),
      ),
    ],
  );
}
