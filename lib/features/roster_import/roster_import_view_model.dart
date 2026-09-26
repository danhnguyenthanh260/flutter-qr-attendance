import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/roster_import.dart';

class RosterImportViewModel extends ChangeNotifier {
  bool _disposed = false;
  void _update(VoidCallback change) {
    if (_disposed) return;
    change();
    notifyListeners();
  }

  void select(String? value) => _update(() => selected = value);
  void filter(String value) => _update(() => search = value);
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  final Map<String, RosterImport> documents = {};
  String? selected;
  String search = '';
  String? error;
  bool busy = false;

  Future<void> loadBundledSources() async {
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
      if (_disposed) return;
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
      if (_disposed) return;
      _update(() {
        documents[id] = result;
        selected = id;
        error = null;
      });
    } catch (_) {
      if (!_disposed) {
        _update(
          () => error = 'Không đọc được file. Hãy chọn file Excel XML (.xls) xuất từ danh sách lớp, tối đa 5 MB.',
        );
      }
    }
  }

  Future<void> pick() async {
    _update(() => busy = true);
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
      if (!_disposed) {
        _update(
          () => error = 'Không mở được cửa sổ chọn file. Vui lòng thử lại.',
        );
      }
    } finally {
      if (!_disposed) _update(() => busy = false);
    }
  }
}
