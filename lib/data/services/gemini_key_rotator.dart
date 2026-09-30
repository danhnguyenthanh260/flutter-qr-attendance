/// Health status and diagnostic metrics of a Gemini API key.
enum KeyHealthStatus { active, rateLimited, invalid }

extension KeyHealthStatusExtension on KeyHealthStatus {
  String get label {
    switch (this) {
      case KeyHealthStatus.active:
        return 'Hoạt động';
      case KeyHealthStatus.rateLimited:
        return 'Chạm giới hạn (429)';
      case KeyHealthStatus.invalid:
        return 'Không hợp lệ / Lỗi';
    }
  }

  bool get isUsable => this == KeyHealthStatus.active;
}

/// Diagnostic information and metrics for an individual API key.
class KeyStatusInfo {
  final int index;
  final String rawKey;
  final String maskedKey;
  final KeyHealthStatus status;
  final int successCount;
  final int failureCount;
  final DateTime? lastUsedAt;
  final String? lastError;

  const KeyStatusInfo({
    required this.index,
    required this.rawKey,
    required this.maskedKey,
    this.status = KeyHealthStatus.active,
    this.successCount = 0,
    this.failureCount = 0,
    this.lastUsedAt,
    this.lastError,
  });

  KeyStatusInfo copyWith({
    KeyHealthStatus? status,
    int? successCount,
    int? failureCount,
    DateTime? lastUsedAt,
    String? lastError,
    bool clearLastError = false,
  }) {
    return KeyStatusInfo(
      index: index,
      rawKey: rawKey,
      maskedKey: maskedKey,
      status: status ?? this.status,
      successCount: successCount ?? this.successCount,
      failureCount: failureCount ?? this.failureCount,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
    );
  }
}

class GeminiKeyRotator {
  final List<String> _keys = [];
  final Map<String, KeyStatusInfo> _keyStats = {};
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

  /// Số lượng key đang ở trạng thái sẵn sàng hoạt động
  int get activeKeyCount =>
      getKeyStatuses().where((s) => s.status == KeyHealthStatus.active).length;

  /// Key đang trỏ tới hiện tại
  String? get currentKey {
    if (_keys.isEmpty) return null;
    return _keys[_currentIndex % _keys.length];
  }

  /// Lấy danh sách chẩn đoán trạng thái của tất cả các keys theo thứ tự
  List<KeyStatusInfo> getKeyStatuses() {
    return List.generate(_keys.length, (i) {
      final key = _keys[i];
      return _keyStats[key] ??
          KeyStatusInfo(index: i, rawKey: key, maskedKey: maskKey(key));
    });
  }

  /// Lấy key tiếp theo theo cơ chế Round-Robin và tự động tăng con trỏ
  String? getNextKey() {
    if (_keys.isEmpty) return null;
    final key = _keys[_currentIndex % _keys.length];
    _currentIndex = (_currentIndex + 1) % _keys.length;
    return key;
  }

  /// Ghi nhận gọi thành công cho key
  void recordSuccess(String key) {
    final trimmed = key.trim();
    final st = _keyStats[trimmed];
    if (st != null) {
      _keyStats[trimmed] = st.copyWith(
        status: KeyHealthStatus.active,
        successCount: st.successCount + 1,
        lastUsedAt: DateTime.now(),
        clearLastError: true,
      );
    }
  }

  /// Khi một key gặp lỗi (429 Rate Limit hoặc 403 Invalid),
  /// hàm này cập nhật trạng thái lỗi của key và đảm bảo con trỏ nhảy sang key tiếp theo ngay lập tức.
  void rotateOnFailure(
    String failedKey, {
    String? reason,
    bool isRateLimit = false,
    bool isInvalid = false,
  }) {
    final trimmed = failedKey.trim();
    if (_keys.isEmpty) return;

    final current = _keys[_currentIndex % _keys.length];
    if (current == trimmed) {
      _currentIndex = (_currentIndex + 1) % _keys.length;
    }

    final st = _keyStats[trimmed];
    if (st != null) {
      KeyHealthStatus newStatus;
      if (isRateLimit) {
        newStatus = KeyHealthStatus.rateLimited;
      } else if (isInvalid) {
        newStatus = KeyHealthStatus.invalid;
      } else if (reason != null &&
          (reason.contains('429') ||
              reason.toLowerCase().contains('quota') ||
              reason.toLowerCase().contains('rate limit'))) {
        newStatus = KeyHealthStatus.rateLimited;
      } else if (reason != null &&
          (reason.contains('400') ||
              reason.contains('401') ||
              reason.contains('403') ||
              reason.toLowerCase().contains('invalid') ||
              reason.toLowerCase().contains('từ chối'))) {
        newStatus = KeyHealthStatus.invalid;
      } else {
        newStatus = KeyHealthStatus.rateLimited;
      }

      _keyStats[trimmed] = st.copyWith(
        status: newStatus,
        failureCount: st.failureCount + 1,
        lastUsedAt: DateTime.now(),
        lastError: reason,
      );
    }
  }

  /// Đặt lại trạng thái sức khỏe của toàn bộ keys về active
  void resetKeyHealth() {
    for (final key in _keys) {
      final st = _keyStats[key];
      if (st != null) {
        _keyStats[key] = st.copyWith(
          status: KeyHealthStatus.active,
          clearLastError: true,
        );
      }
    }
  }

  static final RegExp _validKeyPattern = RegExp(r'^[A-Za-z0-9_\-\.]+$');

  /// Cập nhật toàn bộ danh sách keys
  void setKeys(List<String> newKeys) {
    final oldStats = Map<String, KeyStatusInfo>.from(_keyStats);
    _keys.clear();
    _keyStats.clear();

    for (final rawKey in newKeys) {
      final trimmed = rawKey.trim();
      if (trimmed.isNotEmpty &&
          _validKeyPattern.hasMatch(trimmed) &&
          !_keys.contains(trimmed)) {
        _keys.add(trimmed);
        final old = oldStats[trimmed];
        _keyStats[trimmed] = KeyStatusInfo(
          index: _keys.length - 1,
          rawKey: trimmed,
          maskedKey: maskKey(trimmed),
          status: old?.status ?? KeyHealthStatus.active,
          successCount: old?.successCount ?? 0,
          failureCount: old?.failureCount ?? 0,
          lastUsedAt: old?.lastUsedAt,
          lastError: old?.lastError,
        );
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
    _keyStats[trimmed] = KeyStatusInfo(
      index: _keys.length - 1,
      rawKey: trimmed,
      maskedKey: maskKey(trimmed),
    );
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
    final removed = _keys.removeAt(index);
    _keyStats.remove(removed);

    // Cập nhật lại chỉ mục (index) cho các key còn lại
    for (var i = 0; i < _keys.length; i++) {
      final k = _keys[i];
      final st = _keyStats[k];
      if (st != null) {
        _keyStats[k] = KeyStatusInfo(
          index: i,
          rawKey: k,
          maskedKey: st.maskedKey,
          status: st.status,
          successCount: st.successCount,
          failureCount: st.failureCount,
          lastUsedAt: st.lastUsedAt,
          lastError: st.lastError,
        );
      }
    }

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
    _keyStats.clear();
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
