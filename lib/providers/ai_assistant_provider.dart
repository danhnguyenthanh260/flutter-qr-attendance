import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';
import '../data/models/ai_chat_message.dart';
import '../data/models/attendance_summary.dart';
import '../data/models/class_model.dart';
import '../data/models/session_day_group.dart';
import '../data/services/gemini_ai_service.dart';
import '../data/services/gemini_key_rotator.dart';

class AiAssistantProvider extends ChangeNotifier {
  final AttendanceAiService _aiService;
  final GeminiKeyRotator _rotator;
  final List<ChatMessage> _messages = [];
  bool _isGenerating = false;
  String? _lastGeneratedReport;

  AiAssistantProvider({
    AttendanceAiService? aiService,
    String? initialApiKey,
    List<String>? initialApiKeys,
  })  : _aiService = aiService ?? GeminiRestService(),
        _rotator = GeminiKeyRotator(
          initialApiKeys ??
              (initialApiKey != null && initialApiKey.isNotEmpty
                  ? [initialApiKey]
                  : AppConfig.initialGeminiApiKeys),
        ) {
    // Thêm tin nhắn chào mừng ban đầu
    _messages.add(
      ChatMessage(
        id: 'msg_welcome',
        sender: MessageSender.ai,
        content:
            'Xin chào Thầy/Cô. Tôi là Trợ lý Chuyên cần & Học vụ.\n\n'
            'Hệ thống hỗ trợ Giảng viên các nghiệp vụ chính:\n'
            '• Cảnh báo học vụ: Danh sách sinh viên vắng tiệm cận 20% và sinh viên bị cấm thi theo môn.\n'
            '• Điểm danh thời gian thực: Tra cứu sinh viên vắng mặt hoặc chưa quét mã trong ca học.\n'
            '• Đánh giá chuyên cần: Thống kê tỷ lệ đi học và phát hiện các lượt quét mã trùng lặp.\n'
            '• Xuất báo cáo: Tổng hợp và tạo văn bản báo cáo chuyên cần chi tiết theo từng lớp.\n\n'
            'Thầy/Cô có thể chọn các tác vụ mẫu bên dưới hoặc nhập câu hỏi trực tiếp.',
        timestamp: DateTime.now(),
      ),
    );
  }

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isGenerating => _isGenerating;
  List<String> get apiKeys => _rotator.keys;
  String get apiKey => _rotator.hasKeys ? _rotator.keys.first : '';
  bool get hasApiKey => _rotator.hasKeys;
  int get keyCount => _rotator.keyCount;
  GeminiKeyRotator get rotator => _rotator;
  String? get lastGeneratedReport => _lastGeneratedReport;

  String get activeKeyStatus {
    if (!_rotator.hasKeys) return 'Local Engine';
    if (_rotator.keyCount == 1) return 'Gemini Online';
    return 'Gemini Rotating (${_rotator.keyCount} Keys)';
  }

  void setApiKey(String key) {
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      _rotator.clear();
    } else {
      _rotator.setKeys([trimmed]);
    }
    notifyListeners();
  }

  void setApiKeys(List<String> keys) {
    _rotator.setKeys(keys);
    notifyListeners();
  }

  bool addApiKey(String key) {
    final added = _rotator.addKey(key);
    if (added) notifyListeners();
    return added;
  }

  int addApiKeysFromText(String text) {
    final count = _rotator.addKeysFromText(text);
    if (count > 0) notifyListeners();
    return count;
  }

  bool removeApiKeyAt(int index) {
    final removed = _rotator.removeKeyAt(index);
    if (removed) notifyListeners();
    return removed;
  }

  void clearApiKeys() {
    _rotator.clear();
    notifyListeners();
  }

  void clearMessages() {
    _messages.clear();
    _messages.add(
      ChatMessage(
        id: 'msg_reset_${DateTime.now().millisecondsSinceEpoch}',
        sender: MessageSender.system,
        content: 'Đã xóa lịch sử trò chuyện.',
        timestamp: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  Future<void> sendMessage({
    required String query,
    AttendanceSummary? currentSummary,
    List<SessionDayGroup>? history,
    ClassModel? currentClass,
  }) async {
    final text = query.trim();
    if (text.isEmpty || _isGenerating) return;

    // 1. Thêm tin nhắn của User
    final userMsg = ChatMessage(
      id: 'msg_user_${DateTime.now().millisecondsSinceEpoch}',
      sender: MessageSender.user,
      content: text,
      timestamp: DateTime.now(),
    );
    _messages.add(userMsg);

    // 2. Thêm tin nhắn đang tải của AI
    final loadingMsg = ChatMessage(
      id: 'msg_ai_${DateTime.now().millisecondsSinceEpoch}',
      sender: MessageSender.ai,
      content: 'Đang phân tích dữ liệu điểm danh...',
      timestamp: DateTime.now(),
      isLoading: true,
    );
    _messages.add(loadingMsg);
    _isGenerating = true;
    notifyListeners();

    // 3. Xây dựng ngữ cảnh và gọi AI
    final context = AttendancePromptBuilder.buildContext(
      summary: currentSummary,
      history: history,
      classModel: currentClass,
    );

    try {
      final responseText = await _aiService.askAi(
        prompt: text,
        context: context,
        apiKeys: _rotator.keys,
      );

      // Thay thế loading message bằng câu trả lời thật
      final index = _messages.indexWhere((m) => m.id == loadingMsg.id);
      if (index != -1) {
        _messages[index] = ChatMessage(
          id: loadingMsg.id,
          sender: MessageSender.ai,
          content: responseText,
          timestamp: DateTime.now(),
          isLoading: false,
        );
      }
    } catch (e) {
      final index = _messages.indexWhere((m) => m.id == loadingMsg.id);
      if (index != -1) {
        _messages[index] = ChatMessage(
          id: loadingMsg.id,
          sender: MessageSender.ai,
          content: '❌ Rất tiếc, đã xảy ra lỗi khi tạo phản hồi: $e',
          timestamp: DateTime.now(),
          isLoading: false,
        );
      }
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }

  Future<String?> generateReport({
    required AttendanceSummary summary,
    List<SessionDayGroup>? history,
    ClassModel? classModel,
  }) async {
    if (_isGenerating) return null;

    _isGenerating = true;
    notifyListeners();

    try {
      final report = await _aiService.generateReport(
        summary: summary,
        history: history,
        classModel: classModel,
        apiKeys: _rotator.keys,
      );
      _lastGeneratedReport = report;

      // Đẩy báo cáo vào khung chat như một tin nhắn nổi bật
      _messages.add(
        ChatMessage(
          id: 'report_${DateTime.now().millisecondsSinceEpoch}',
          sender: MessageSender.ai,
          content: report,
          timestamp: DateTime.now(),
          isReport: true,
        ),
      );
      return report;
    } catch (e) {
      _messages.add(
        ChatMessage(
          id: 'report_err_${DateTime.now().millisecondsSinceEpoch}',
          sender: MessageSender.ai,
          content: '❌ Lỗi khi khởi tạo báo cáo tự động: $e',
          timestamp: DateTime.now(),
        ),
      );
      return null;
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }
}
