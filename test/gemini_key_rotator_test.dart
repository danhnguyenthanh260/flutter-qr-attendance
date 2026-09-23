import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_qr_attendance/data/services/gemini_key_rotator.dart';

void main() {
  group('GeminiKeyRotator Tests', () {
    test('Khởi tạo rỗng và với danh sách ban đầu', () {
      final emptyRotator = GeminiKeyRotator();
      expect(emptyRotator.hasKeys, isFalse);
      expect(emptyRotator.keyCount, 0);
      expect(emptyRotator.getNextKey(), isNull);
      expect(emptyRotator.currentKey, isNull);

      final rotator = GeminiKeyRotator(['KEY_1', 'KEY_2']);
      expect(rotator.hasKeys, isTrue);
      expect(rotator.keyCount, 2);
      expect(rotator.keys, ['KEY_1', 'KEY_2']);
    });

    test('Xoay vòng Round-Robin tuần tự qua các keys', () {
      final rotator = GeminiKeyRotator(['KEY_A', 'KEY_B', 'KEY_C']);

      expect(rotator.getNextKey(), 'KEY_A');
      expect(rotator.getNextKey(), 'KEY_B');
      expect(rotator.getNextKey(), 'KEY_C');
      // Quay vòng lại từ đầu
      expect(rotator.getNextKey(), 'KEY_A');
      expect(rotator.getNextKey(), 'KEY_B');
    });

    test('Tự động nhảy sang key tiếp theo khi rotateOnFailure', () {
      final rotator = GeminiKeyRotator(['KEY_A', 'KEY_B', 'KEY_C']);
      expect(rotator.currentKey, 'KEY_A');

      rotator.rotateOnFailure('KEY_A');
      expect(rotator.currentKey, 'KEY_B');

      rotator.rotateOnFailure('KEY_B');
      expect(rotator.currentKey, 'KEY_C');

      rotator.rotateOnFailure('KEY_C');
      expect(rotator.currentKey, 'KEY_A');
    });

    test('Thêm key đơn và lọc trùng lặp', () {
      final rotator = GeminiKeyRotator();
      expect(rotator.addKey('  KEY_1  '), isTrue);
      expect(rotator.addKey('KEY_1'), isFalse); // trùng
      expect(rotator.addKey('   '), isFalse); // rỗng
      expect(rotator.keyCount, 1);
      expect(rotator.keys.first, 'KEY_1');
    });

    test('Thêm nhiều keys từ văn bản phân tách bởi dấu phẩy, chấm phẩy, xuống dòng', () {
      final rotator = GeminiKeyRotator();
      final count = rotator.addKeysFromText('KEY_1, KEY_2; KEY_3\nKEY_4');

      expect(count, 4);
      expect(rotator.keyCount, 4);
      expect(rotator.keys, ['KEY_1', 'KEY_2', 'KEY_3', 'KEY_4']);
    });

    test('Xóa key tại vị trí và cập nhật con trỏ', () {
      final rotator = GeminiKeyRotator(['KEY_1', 'KEY_2', 'KEY_3']);
      expect(rotator.removeKeyAt(1), isTrue); // Xóa KEY_2
      expect(rotator.keys, ['KEY_1', 'KEY_3']);
      expect(rotator.keyCount, 2);

      expect(rotator.removeKeyAt(99), isFalse); // ngoài dải
    });

    test('Che bảo mật API key (maskKey)', () {
      expect(
        GeminiKeyRotator.maskKey('AIzaSyD9823hjasd8234j1k9'),
        'AIzaSy...j1k9',
      );
      expect(
        GeminiKeyRotator.maskKey('12345'),
        '••••••••',
      );
    });
  });
}
