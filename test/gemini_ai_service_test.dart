import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_qr_attendance/data/models/attendance_summary.dart';
import 'package:flutter_qr_attendance/data/models/session_model.dart';
import 'package:flutter_qr_attendance/data/services/gemini_ai_service.dart';

import 'helpers/attendance_fixtures.dart';

void main() {
  late AttendanceSummary sampleSummary;

  setUp(() {
    final session = buildSession(id: 'SES_TEST', status: SessionStatus.closed);
    final roster1 = buildRosterEntry('student1@fpt.edu.vn', name: 'Nguyễn Văn A');
    final roster2 = buildRosterEntry('student2@fpt.edu.vn', name: 'Trần Thị B');

    final row1 = StudentAttendanceRow(
      student: roster1,
      status: StudentAttendanceStatus.present,
      acceptedAt: DateTime(2026, 9, 22, 9, 20),
    );
    final row2 = StudentAttendanceRow(
      student: roster2,
      status: StudentAttendanceStatus.absent,
    );

    final attempt = buildAttempt(
      'student1@fpt.edu.vn',
      attemptType: 'duplicate_email',
      occurredAt: DateTime(2026, 9, 22, 9, 25),
    );
    final retryEvent = RetryEvent(
      attempt: attempt,
      displayName: 'Nguyễn Văn A (student1@fpt.edu.vn)',
      isOnRoster: true,
    );

    sampleSummary = AttendanceSummary(
      scope: const AttendanceScope(
        classId: 'CLASS_TEST',
        className: 'PRM392 - Flutter',
        date: '2026-09-22',
        slotNumber: 2,
        timeRange: '09:15 - 10:45',
        sessionIds: ['SES_TEST'],
      ),
      sessions: [session],
      rows: [row1, row2],
      retryEvents: [retryEvent],
      unlistedSubmissions: const [],
      rosterChangedBetweenSessions: false,
      asOf: DateTime(2026, 9, 22, 10, 45),
    );
  });

  group('AttendancePromptBuilder', () {
    test('xây dựng ngữ cảnh đầy đủ từ AttendanceSummary', () {
      final context = AttendancePromptBuilder.buildContext(summary: sampleSummary);

      expect(context, contains('PRM392 - Flutter'));
      expect(context, contains('Tổng sĩ số lớp: 2'));
      expect(context, contains('CÓ MẶT: 1 sinh viên (50.0%)'));
      expect(context, contains('VẮNG / CHƯA ĐIỂM DANH: 1 sinh viên'));
      expect(context, contains('Trần Thị B'));
      expect(context, contains('CẢNH BÁO NỘP TRÙNG LẶP'));
      expect(context, contains('student1@fpt.edu.vn'));
      expect(context, contains('THỐNG KÊ TÍCH LŨY CẢ KỲ & CẢNH BÁO CẤM THI'));
      expect(context, contains('20% TỔNG SỐ SLOT'));
    });
  });

  group('LocalAttendanceAiService', () {
    final localAi = LocalAttendanceAiService();

    test('cảnh báo chính xác sinh viên vắng gần 20% và bị cấm thi', () async {
      final context = AttendancePromptBuilder.buildContext(summary: sampleSummary);
      final response = await localAi.askAi(
        prompt: 'Ai vắng gần 20% và ai bị cấm thi?',
        context: context,
      );

      expect(response, contains('CẢNH BÁO HỌC VỤ & NGUY CƠ CẤM THI'));
      expect(response, contains('NHÓM BỊ CẤM THI'));
      expect(response, contains('NHÓM NGUY CƠ CẤM THI'));
      expect(response, contains('Email'));
    });

    test('hiển thị chi tiết sinh viên bị cấm thi và nguy cơ khi có trong context', () async {
      const customContext = '''
=== DỮ LIỆU ĐIỂM DANH HIỆN TẠI ===
Môn học / Lớp: PRM392 - Flutter
Tổng sĩ số lớp: 2 sinh viên
--- DANH SÁCH SINH VIÊN BỊ CẤM THI (VẮNG >= 20% TỔNG SỐ SLOT) ---
1. Nguyễn Văn A | Email: annd@fpt.edu.vn | Đã vắng: 7/30 slot (23.3%) | Trạng thái: CẤM THI
--- DANH SÁCH SINH VIÊN NGUY CƠ CẤM THI (VẮNG GẦN 20% - TIỆM CẬN NGƯỠNG) ---
1. Trần Thị B | Email: binhtt@fpt.edu.vn | Đã vắng: 5/30 slot (16.7%) | Còn được phép nghỉ tối đa: 0 buổi
''';
      final response = await localAi.askAi(
        prompt: 'Danh sách sinh viên cấm thi và vắng gần 20%?',
        context: customContext,
      );

      expect(response, contains('annd@fpt.edu.vn'));
      expect(response, contains('binhtt@fpt.edu.vn'));
      expect(response, contains('7/30 slot'));
      expect(response, contains('5/30 slot'));
    });

    test('trả lời chính xác câu hỏi về sinh viên vắng', () async {
      final context = AttendancePromptBuilder.buildContext(summary: sampleSummary);
      final response = await localAi.askAi(
        prompt: 'Hôm nay có những bạn nào vắng?',
        context: context,
      );

      expect(response, contains('Trần Thị B'));
      expect(response, contains('student2@fpt.edu.vn'));
    });

    test('trả lời chính xác câu hỏi về tỷ lệ chuyên cần', () async {
      final context = AttendancePromptBuilder.buildContext(summary: sampleSummary);
      final response = await localAi.askAi(
        prompt: 'Tỷ lệ chuyên cần của lớp hôm nay là bao nhiêu?',
        context: context,
      );

      expect(response, contains('50.0%'));
      expect(response, contains('1 bạn'));
    });

    test('trả lời chính xác câu hỏi về nộp trùng lặp', () async {
      final context = AttendancePromptBuilder.buildContext(summary: sampleSummary);
      final response = await localAi.askAi(
        prompt: 'Có sinh viên nào nộp trùng lặp không?',
        context: context,
      );

      expect(response, contains('student1@fpt.edu.vn'));
      expect(response, contains('duplicate'));
    });

    test('tạo báo cáo chuyên cần định dạng Markdown chuẩn bao gồm cảnh báo cấm thi', () async {
      final report = await localAi.generateReport(summary: sampleSummary);

      expect(report, contains('# BÁO CÁO CHUYÊN CẦN BUỔI HỌC'));
      expect(report, contains('PRM392 - Flutter'));
      expect(report, contains('50.0%'));
      expect(report, contains('Cảnh báo Học vụ & Nguy cơ Cấm thi'));
      expect(report, contains('Email'));
      expect(report, contains('Trần Thị B'));
      expect(report, contains('Cảnh báo nộp trùng'));
    });
  });

  group('GeminiRestService', () {
    test('gọi REST API của Gemini và phân tích kết quả trả về', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.host, 'generativelanguage.googleapis.com');
        expect(request.url.queryParameters['key'], 'test_api_key');

        final responseBody = {
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': 'Hôm nay có 1 sinh viên vắng mặt là Trần Thị B.'}
                ]
              }
            }
          ]
        };

        return http.Response.bytes(
          utf8.encode(jsonEncode(responseBody)),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = GeminiRestService(client: mockClient);
      final answer = await service.askAi(
        prompt: 'Ai vắng?',
        context: 'Ngữ cảnh điểm danh',
        apiKey: 'test_api_key',
      );

      expect(answer, 'Hôm nay có 1 sinh viên vắng mặt là Trần Thị B.');
    });

    test('tự động failover sang key thứ hai khi key đầu tiên bị 429 Rate Limit', () async {
      final keysCalled = <String>[];
      final mockClient = MockClient((request) async {
        final key = request.url.queryParameters['key']!;
        keysCalled.add(key);

        if (key == 'KEY_1') {
          // Key 1 bị 429 Rate Limit
          return http.Response('{"error": "Resource has been exhausted"}', 429);
        }

        // Key 2 thành công
        final responseBody = {
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': 'Phản hồi thành công từ Key 2!'}
                ]
              }
            }
          ]
        };
        return http.Response.bytes(
          utf8.encode(jsonEncode(responseBody)),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = GeminiRestService(client: mockClient);
      final answer = await service.askAi(
        prompt: 'Ai vắng?',
        context: 'Ngữ cảnh điểm danh',
        apiKeys: ['KEY_1', 'KEY_2'],
      );

      expect(keysCalled, ['KEY_1', 'KEY_2']);
      expect(answer, 'Phản hồi thành công từ Key 2!');
    });

    test('fallback sang Local Engine khi không có API key', () async {
      final service = GeminiRestService();
      final context = AttendancePromptBuilder.buildContext(summary: sampleSummary);

      final answer = await service.askAi(
        prompt: 'Ai vắng?',
        context: context,
        apiKey: '',
      );

      expect(answer, contains('Trần Thị B'));
    });
  });
}
