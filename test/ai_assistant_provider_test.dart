import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_qr_attendance/data/models/ai_chat_message.dart';
import 'package:flutter_qr_attendance/data/models/attendance_summary.dart';
import 'package:flutter_qr_attendance/data/models/session_model.dart';
import 'package:flutter_qr_attendance/data/services/gemini_ai_service.dart';
import 'package:flutter_qr_attendance/providers/ai_assistant_provider.dart';

import 'helpers/attendance_fixtures.dart';

class MockAiService implements AttendanceAiService {
  @override
  Future<String> askAi({
    required String prompt,
    required String context,
    String? apiKey,
  }) async {
    return 'Phản hồi giả lập cho: $prompt';
  }

  @override
  Future<String> generateReport({
    required AttendanceSummary summary,
    dynamic history,
    dynamic classModel,
    String? apiKey,
  }) async {
    return 'Báo cáo giả lập cho ${summary.scope.className}';
  }
}

void main() {
  late AiAssistantProvider provider;
  late AttendanceSummary sampleSummary;

  setUp(() {
    provider = AiAssistantProvider(
      aiService: MockAiService(),
      initialApiKey: 'test_key',
    );

    final session = buildSession(id: 'SES_1', status: SessionStatus.closed);
    sampleSummary = AttendanceSummary(
      scope: const AttendanceScope(
        classId: 'CLASS_TEST',
        className: 'PRM392',
        date: '2026-09-22',
        slotNumber: 1,
        timeRange: '07:30 - 09:00',
        sessionIds: ['SES_1'],
      ),
      sessions: [session],
      rows: const [],
      retryEvents: const [],
      unlistedSubmissions: const [],
      rosterChangedBetweenSessions: false,
      asOf: DateTime(2026, 9, 22),
    );
  });

  test('khởi tạo với tin nhắn chào mừng mặc định', () {
    expect(provider.messages, isNotEmpty);
    expect(provider.messages.first.id, 'msg_welcome');
    expect(provider.apiKey, 'test_key');
    expect(provider.hasApiKey, isTrue);
  });

  test('gửi tin nhắn thêm câu hỏi và nhận câu trả lời từ AI', () async {
    await provider.sendMessage(
      query: 'Lớp hôm nay có bao nhiêu bạn?',
      currentSummary: sampleSummary,
    );

    expect(provider.messages.length, greaterThanOrEqualTo(3));
    final userMsg = provider.messages.firstWhere((m) => m.sender == MessageSender.user);
    expect(userMsg.content, 'Lớp hôm nay có bao nhiêu bạn?');

    final lastAiMsg = provider.messages.last;
    expect(lastAiMsg.sender, MessageSender.ai);
    expect(lastAiMsg.content, contains('Phản hồi giả lập cho: Lớp hôm nay có bao nhiêu bạn?'));
    expect(lastAiMsg.isLoading, isFalse);
  });

  test('tạo báo cáo chuyên cần thành công', () async {
    final report = await provider.generateReport(summary: sampleSummary);

    expect(report, contains('Báo cáo giả lập cho PRM392'));
    expect(provider.lastGeneratedReport, report);

    final reportMsg = provider.messages.last;
    expect(reportMsg.isReport, isTrue);
    expect(reportMsg.content, report);
  });

  test('cập nhật API key và xóa lịch sử tin nhắn', () {
    provider.setApiKey('new_gemini_key');
    expect(provider.apiKey, 'new_gemini_key');

    provider.clearMessages();
    expect(provider.messages.length, 1);
    expect(provider.messages.first.sender, MessageSender.system);
  });
}
