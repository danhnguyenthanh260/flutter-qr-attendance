import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';
import '../data/models/ai_chat_message.dart';
import '../data/models/attendance_summary.dart';
import '../data/models/class_model.dart';
import '../data/models/session_day_group.dart';
import '../data/services/gemini_ai_service.dart';

class AiAssistantProvider extends ChangeNotifier {
  final AttendanceAiService _aiService;
  String _apiKey;
  final List<ChatMessage> _messages = [];
  bool _isGenerating = false;
  String? _lastGeneratedReport;

  AiAssistantProvider({
    AttendanceAiService? aiService,
    String? initialApiKey,
  })  : _aiService = aiService ?? GeminiRestService(),
        _apiKey = initialApiKey ?? AppConfig.geminiApiKey {
    // Thêm tin nhắn chào mừng ban đầu
    _messages.add(
      ChatMessage(
        id: 'msg_welcome',
        sender: MessageSender.ai,
        content:
            'Xin chào! Tôi là **Trợ lý AI Điểm danh** 🤖\n\n'
            'Tôi có thể giúp bạn:\n'
            '• Cảnh báo học vụ: Danh sách sinh viên vắng gần 20% & sinh viên BỊ CẤM THI.\n'
            '• Tra cứu nhanh danh sách sinh viên vắng mặt hoặc chưa quét mã hôm nay.\n'
            '• Đánh giá tỷ lệ chuyên cần của lớp học theo thời gian thực.\n'
            '• Phát hiện các dấu hiệu nộp trùng lặp hoặc nghi vấn gian lận.\n'
            '• Tự động tạo Báo cáo Tổng quan chuyên cần chỉ với 1 cú nhấp chuột.\n\n'
            'Bạn có thể bấm vào các gợi ý bên dưới hoặc gõ câu hỏi để bắt đầu!',
        timestamp: DateTime.now(),
      ),
    );
  }

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isGenerating => _isGenerating;
  String get apiKey => _apiKey;
  bool get hasApiKey => _apiKey.trim().isNotEmpty;
  String? get lastGeneratedReport => _lastGeneratedReport;

  void setApiKey(String key) {
    _apiKey = key.trim();
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
        apiKey: _apiKey,
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
        apiKey: _apiKey,
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
