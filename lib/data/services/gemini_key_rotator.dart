class GeminiKeyRotator {
  final List<String> _keys = [];
  int _currentIndex = 0;

  GeminiKeyRotator([List<String>? initialKeys]) {
    if (initialKeys != null) {
      setKeys(initialKeys);
    }
  }

  /// Danh sách các API keys hiện có (không sửa đổi trực tiếp)
  List<String> get keys => List.unmodifiable(_keys);

  /// Số lượng keys hiện có trong pool xoay vòng
  int get keyCount => _keys.length;

  /// Có ít nhất một API key hợp lệ hay không
  bool get hasKeys => _keys.isNotEmpty;

  /// Key đang trỏ tới hiện tại
  String? get currentKey {
    if (_keys.isEmpty) return null;
    return _keys[_currentIndex % _keys.length];
  }

  /// Lấy key tiếp theo theo cơ chế Round-Robin và tự động tăng con trỏ
  String? getNextKey() {
    if (_keys.isEmpty) return null;
    final key = _keys[_currentIndex % _keys.length];
    _currentIndex = (_currentIndex + 1) % _keys.length;
    return key;
  }

  /// Khi một key gặp lỗi (429 Rate Limit hoặc 403 Invalid),
  /// hàm này đảm bảo con trỏ nhảy sang key tiếp theo ngay lập tức.
  void rotateOnFailure(String failedKey) {
    if (_keys.isEmpty) return;
    final current = _keys[_currentIndex % _keys.length];
    if (current == failedKey.trim()) {
      _currentIndex = (_currentIndex + 1) % _keys.length;
    }
  }

  static final RegExp _validKeyPattern = RegExp(r'^[A-Za-z0-9_\-\.]+$');

  /// Cập nhật toàn bộ danh sách keys
  void setKeys(List<String> newKeys) {
    _keys.clear();
    for (final rawKey in newKeys) {
      final trimmed = rawKey.trim();
      if (trimmed.isNotEmpty &&
          _validKeyPattern.hasMatch(trimmed) &&
          !_keys.contains(trimmed)) {
        _keys.add(trimmed);
      }
    }
    _currentIndex = 0;
  }

  /// Thêm một key mới vào pool xoay vòng
  bool addKey(String key) {
    final trimmed = key.trim();
    if (trimmed.isEmpty ||
        !_validKeyPattern.hasMatch(trimmed) ||
        _keys.contains(trimmed)) {
      return false;
    }
    _keys.add(trimmed);
    return true;
  }

  /// Thêm nhiều keys từ chuỗi văn bản (phân tách bởi dấu phẩy, chấm phẩy hoặc xuống dòng)
  int addKeysFromText(String text) {
    final parts = text.split(RegExp(r'[,;\n]'));
    var count = 0;
    for (final part in parts) {
      if (addKey(part)) {
        count++;
      }
    }
    return count;
  }

  /// Xóa key tại chỉ mục xác định
  bool removeKeyAt(int index) {
    if (index < 0 || index >= _keys.length) {
      return false;
    }
    _keys.removeAt(index);
    if (_keys.isEmpty) {
      _currentIndex = 0;
    } else {
      _currentIndex = _currentIndex % _keys.length;
    }
    return true;
  }

  /// Xóa toàn bộ keys (chuyển về chế độ Local Engine)
  void clear() {
    _keys.clear();
    _currentIndex = 0;
  }

  /// Che bảo mật cho key (ví dụ: AIzaSy...4xK9)
  static String maskKey(String key) {
    final trimmed = key.trim();
    if (trimmed.length <= 10) {
      return '••••••••';
    }
    final prefix = trimmed.substring(0, 6);
    final suffix = trimmed.substring(trimmed.length - 4);
    return '$prefix...$suffix';
  }
}
