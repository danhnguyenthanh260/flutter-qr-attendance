import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../models/attendance_summary.dart';
import '../models/class_model.dart';
import '../models/session_day_group.dart';
import '../models/student_absence_warning.dart';
import 'gemini_key_rotator.dart';

abstract class AttendanceAiService {
  Future<String> askAi({
    required String prompt,
    required String context,
    String? apiKey,
    List<String>? apiKeys,
  });

  Future<String> generateReport({
    required AttendanceSummary summary,
    List<SessionDayGroup>? history,
    ClassModel? classModel,
    String? apiKey,
    List<String>? apiKeys,
  });
}

class AttendancePromptBuilder {
  static String buildContext({
    AttendanceSummary? summary,
    List<SessionDayGroup>? history,
    ClassModel? classModel,
    int? totalSlots,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('=== DỮ LIỆU ĐIỂM DANH HIỆN TẠI ===');

    if (summary == null) {
      buffer.writeln('Chưa có phiên điểm danh nào được chọn hoặc đang mở.');
    } else {
      final scope = summary.scope;
      final timeFormat = DateFormat('HH:mm:ss');
      final percent = summary.totalStudents > 0
          ? ((summary.presentCount / summary.totalStudents) * 100).toStringAsFixed(1)
          : '0.0';

      buffer.writeln('Môn học / Lớp: ${scope.className}');
      buffer.writeln('Ngày: ${scope.date} | Ca học: Slot ${scope.slotNumber} (${scope.timeRange})');
      buffer.writeln('Trạng thái phiên: ${summary.isFinalized ? "ĐÃ CHỐT SỔ" : "ĐANG MỞ (TẠM TÍNH)"}');
      buffer.writeln('Tổng sĩ số lớp: ${summary.totalStudents} sinh viên');
      buffer.writeln('Số sinh viên CÓ MẶT: ${summary.presentCount} sinh viên ($percent%)');
      buffer.writeln('Số sinh viên VẮNG / CHƯA ĐIỂM DANH: ${summary.pendingCount} sinh viên');
      buffer.writeln('Số sự kiện cảnh báo nộp trùng / nghi vấn: ${summary.retryEventCount} lượt');

      // Danh sách vắng
      final absentRows = summary.rows
          .where((r) => r.status != StudentAttendanceStatus.present)
          .toList();
      if (absentRows.isNotEmpty) {
        buffer.writeln('\n--- DANH SÁCH SINH VIÊN VẮNG HOẶC CHƯA ĐIỂM DANH Ở BUỔI HIỆN TẠI ---');
        for (var i = 0; i < absentRows.length; i++) {
          final row = absentRows[i];
          buffer.writeln('${i + 1}. ${row.student.displayName} (${row.student.email}) - Trạng thái: ${row.status.name}');
        }
      }

      // Danh sách có mặt
      final presentRows = summary.rows
          .where((r) => r.status == StudentAttendanceStatus.present)
          .toList();
      if (presentRows.isNotEmpty) {
        buffer.writeln('\n--- DANH SÁCH SINH VIÊN ĐÃ ĐIỂM DANH CÓ MẶT ---');
        for (var i = 0; i < presentRows.length; i++) {
          final row = presentRows[i];
          final timeStr = row.acceptedAt != null ? timeFormat.format(row.acceptedAt!) : 'N/A';
          buffer.writeln('${i + 1}. ${row.student.displayName} (${row.student.email}) - Thời gian quét: $timeStr');
        }
      }

      // Cảnh báo trùng lặp
      if (summary.retryEvents.isNotEmpty) {
        buffer.writeln('\n--- CẢNH BÁO NỘP TRÙNG LẶP / GIAN LẬN ---');
        for (var i = 0; i < summary.retryEvents.length; i++) {
          final evt = summary.retryEvents[i];
          final timeStr = evt.occurredAt != null ? timeFormat.format(evt.occurredAt!) : 'N/A';
          buffer.writeln('${i + 1}. ${evt.displayName} - Lúc: $timeStr - Ghi chú: ${evt.attempt.attemptType}');
        }
      }

      // Cảnh báo tích lũy học kỳ & Nguy cơ cấm thi theo quy chế 20%
      final effectiveTotalSlots = totalSlots ?? classModel?.totalSlots ?? 20;
      final absenceRecords = CourseAbsenceTracker.analyzeClassAbsences(
        currentSummary: summary,
        classModel: classModel,
        totalSlots: effectiveTotalSlots,
      );
      final barredStudents = absenceRecords.where((r) => r.isBarred).toList();
      final dangerStudents = absenceRecords.where((r) => r.isNearDanger).toList();
      final maxAllowed = (effectiveTotalSlots * 0.20).floor();
      final barredMin = maxAllowed + 1;

      buffer.writeln('\n=== THỐNG KÊ TÍCH LŨY CẢ KỲ & CẢNH BÁO CẤM THI (QUY CHẾ FPTU: VẮNG QUÁ 20% TỔNG SỐ SLOT) ===');
      buffer.writeln('• Quy định môn học: $effectiveTotalSlots slots/kỳ. Được phép vắng tối đa: $maxAllowed slots (≤ 20%). Cấm thi khi vắng từ $barredMin slots trở lên (> 20%).');
      buffer.writeln('• Email là định danh duy nhất của mỗi sinh viên trong hệ thống.');

      if (barredStudents.isNotEmpty) {
        buffer.writeln('\n--- DANH SÁCH SINH VIÊN BỊ CẤM THI (VẮNG QUÁ 20% TỔNG SỐ SLOT) ---');
        for (var i = 0; i < barredStudents.length; i++) {
          final s = barredStudents[i];
          buffer.writeln('${i + 1}. ${s.studentName} | Email: ${s.email} | Đã vắng: ${s.totalAbsentSlots}/$effectiveTotalSlots slot (${s.absenceRate.toStringAsFixed(1)}%) | Trạng thái: CẤM THI');
        }
      } else {
        buffer.writeln('\n--- DANH SÁCH SINH VIÊN BỊ CẤM THI: Hiện tại chưa có sinh viên nào vắng quá 20% (trên $maxAllowed slot).');
      }

      if (dangerStudents.isNotEmpty) {
        buffer.writeln('\n--- DANH SÁCH SINH VIÊN NGUY CƠ CẤM THI (VẮNG GẦN HOẶC CHẠM 20%) ---');
        for (var i = 0; i < dangerStudents.length; i++) {
          final s = dangerStudents[i];
          buffer.writeln('${i + 1}. ${s.studentName} | Email: ${s.email} | Đã vắng: ${s.totalAbsentSlots}/$effectiveTotalSlots slot (${s.absenceRate.toStringAsFixed(1)}%) | Còn được phép nghỉ tối đa: ${s.remainingAllowedSlots} buổi');
        }
      } else {
        buffer.writeln('\n--- DANH SÁCH SINH VIÊN NGUY CƠ CẤM THI: Không có sinh viên nào ở vùng nguy cơ tiệm cận ngưỡng.');
      }
    }

    if (history != null && history.isNotEmpty) {
      buffer.writeln('\n=== LỊCH SỬ CÁC BUỔI HỌC TRƯỚC ĐÓ ===');
      for (final group in history) {
        buffer.writeln('• Ngày ${group.date}: ${group.sessions.length} phiên học.');
      }
    }

    return buffer.toString();
  }
}

class GeminiRestService implements AttendanceAiService {
  final http.Client _client;
  final GeminiKeyRotator _rotator;
  static const String _geminiModel = 'gemini-1.5-flash';
  static const String _apiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/$_geminiModel:generateContent';

  GeminiRestService({http.Client? client, GeminiKeyRotator? rotator})
      : _client = client ?? http.Client(),
        _rotator = rotator ?? GeminiKeyRotator();

  GeminiKeyRotator get rotator => _rotator;

  @override
  Future<String> askAi({
    required String prompt,
    required String context,
    String? apiKey,
    List<String>? apiKeys,
  }) async {
    if (apiKeys != null && apiKeys.isNotEmpty) {
      _rotator.setKeys(apiKeys);
    } else if (apiKey != null && apiKey.trim().isNotEmpty) {
      _rotator.setKeys([apiKey.trim()]);
    }

    if (!_rotator.hasKeys) {
      // Fallback sang Local Analytical Engine nếu chưa có key
      return LocalAttendanceAiService().askAi(
        prompt: prompt,
        context: context,
      );
    }

    final systemInstruction =
        'Bạn là Trợ lý AI phân tích điểm danh chuyên nghiệp cho giảng viên trong hệ thống QR Attendance trường FPT University. '
        'Hãy trả lời ngắn gọn, chính xác, súc tích, văn phong sư phạm và hữu ích bằng Tiếng Việt. '
        'ĐẶC BIỆT LƯU Ý: Email là mã định danh duy nhất của mỗi sinh viên trong hệ thống; luôn hiển thị đầy đủ Email của sinh viên khi nhắc đến tên. '
        'Theo Quy chế đào tạo FPT University, sinh viên được phép vắng tối đa 20% tổng số slot của môn học. '
        'Vắng đúng 20% vẫn được thi (chạm ngưỡng tối đa, còn 0 buổi). '
        'Chỉ khi sinh viên vắng QUÁ 20% tổng số slot (> 20%) mới BỊ CẤM THI (Barred from Exam). '
        'Khi được hỏi về sinh viên vắng nhiều, vắng gần hoặc quá 20%, hoặc cấm thi: hãy phân tách rõ ràng 2 nhóm: '
        '(1) Nhóm BỊ CẤM THI (vắng quá 20% tổng số slot môn học), '
        '(2) Nhóm NGUY CƠ CẤM THI (vắng gần hoặc chạm 20%, còn 0-1 buổi) kèm số buổi tối đa còn được phép nghỉ trước khi cấm thi. '
        'Luôn căn cứ hoàn toàn vào DỮ LIỆU ĐIỂM DANH ĐƯỢC CUNG CẤP bên dưới để trả lời đúng sự thật.';

    final payload = {
      'contents': [
        {
          'role': 'user',
          'parts': [
            {
              'text': '$context\n\n=== CÂU HỎI CỦA GIẢNG VIÊN ===\n$prompt',
            }
          ]
        }
      ],
      'systemInstruction': {
        'parts': [
          {'text': systemInstruction}
        ]
      },
      'generationConfig': {
        'temperature': 0.2,
        'maxOutputTokens': 1200,
      }
    };

    final totalKeys = _rotator.keyCount;
    String? lastError;

    // Vòng lặp xoay vòng và tự động failover sang key tiếp theo nếu gặp lỗi
    for (var attempt = 0; attempt < totalKeys; attempt++) {
      final key = _rotator.getNextKey();
      if (key == null || key.isEmpty) break;

      final uri = Uri.parse('$_apiBaseUrl?key=$key');

      try {
        final response = await _client
            .post(
              uri,
              headers: {'Content-Type': 'application/json; charset=utf-8'},
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
          final candidates = data['candidates'] as List?;
          if (candidates != null && candidates.isNotEmpty) {
            final content = candidates[0]['content'] as Map<String, dynamic>?;
            final parts = content?['parts'] as List?;
            if (parts != null && parts.isNotEmpty) {
              return parts[0]['text'] as String? ?? 'Không nhận được phản hồi từ AI.';
            }
          }
          return 'Không thể phân tích phản hồi từ Gemini API.';
        } else if (response.statusCode == 429) {
          // Quota / Rate limit error -> tự động chuyển sang key kế tiếp
          _rotator.rotateOnFailure(key);
          lastError = 'Key ${GeminiKeyRotator.maskKey(key)} đã chạm ngưỡng Rate Limit (429).';
          continue;
        } else if (response.statusCode == 400 || response.statusCode == 403) {
          // Key không hợp lệ hoặc bị từ chối
          _rotator.rotateOnFailure(key);
          lastError = 'Key ${GeminiKeyRotator.maskKey(key)} không hợp lệ hoặc bị từ chối (${response.statusCode}).';
          continue;
        } else {
          lastError = 'Gemini API trả về mã lỗi: ${response.statusCode}. Chi tiết: ${response.body}';
          continue;
        }
      } catch (e) {
        lastError = 'Lỗi kết nối khi gọi Key ${GeminiKeyRotator.maskKey(key)}: $e';
        continue;
      }
    }

    // Khi tất cả keys đều thất bại, fallback sang Local Engine để không gián đoạn
    final fallbackResponse = await LocalAttendanceAiService().askAi(
      prompt: prompt,
      context: context,
    );
    return '$fallbackResponse\n\n*(Lưu ý: Tất cả $totalKeys Gemini API Key đều không khả dụng ($lastError). Hệ thống đã tự động chuyển sang phân tích nội suy cục bộ)*';
  }

  @override
  Future<String> generateReport({
    required AttendanceSummary summary,
    List<SessionDayGroup>? history,
    ClassModel? classModel,
    String? apiKey,
    List<String>? apiKeys,
  }) async {
    final candidateKeys = (apiKeys != null && apiKeys.isNotEmpty)
        ? apiKeys
        : (apiKey != null && apiKey.trim().isNotEmpty ? [apiKey.trim()] : _rotator.keys);

    if (candidateKeys.isEmpty) {
      return LocalAttendanceAiService().generateReport(
        summary: summary,
        history: history,
        classModel: classModel,
      );
    }

    final context = AttendancePromptBuilder.buildContext(
      summary: summary,
      history: history,
      classModel: classModel,
    );

    final prompt =
        'Hãy tạo một BÁO CÁO TỔNG QUAN CHUYÊN CẦN BUỔI HỌC chuyên nghiệp bằng Markdown theo cấu trúc sau:\n'
        '1. Tiêu đề báo cáo và thông tin phiên (Môn học, Ngày, Slot, Trạng thái).\n'
        '2. Số liệu then chốt (Sĩ số, Có mặt, Vắng, Tỷ lệ chuyên cần %).\n'
        '3. Nhận xét & Đánh giá mức độ chuyên cần của sinh viên lớp.\n'
        '4. Cảnh báo Học vụ & Nguy cơ Cấm thi (Quy chế > 20% tổng số slot): Liệt kê sinh viên bị cấm thi và sinh viên vắng gần 20% kèm Email định danh duy nhất của từng sinh viên.\n'
        '5. Danh sách sinh viên vắng mặt ở buổi học hiện tại.\n'
        '6. Cảnh báo các bất thường hoặc gian lận nộp trùng (nếu có).\n'
        '7. Đề xuất/Khuyến nghị cho giảng viên buổi học tiếp theo.';

    return askAi(prompt: prompt, context: context, apiKeys: candidateKeys);
  }
}

class LocalAttendanceAiService implements AttendanceAiService {
  @override
  Future<String> askAi({
    required String prompt,
    required String context,
    String? apiKey,
    List<String>? apiKeys,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final lowerPrompt = prompt.toLowerCase();

    // 1. Phân tích Cảnh báo vắng gần 20% & Cấm thi (Quy chế FPT University)
    if (lowerPrompt.contains('cấm thi') ||
        lowerPrompt.contains('20%') ||
        lowerPrompt.contains('nguy cơ') ||
        lowerPrompt.contains('vắng nhiều') ||
        lowerPrompt.contains('vắng quá') ||
        lowerPrompt.contains('vắng gần') ||
        lowerPrompt.contains('cảnh báo')) {
      final slotMatch = RegExp(r'Quy định môn học:\s*(\d+)\s*slots/kỳ').firstMatch(context);
      final totalSlots = slotMatch != null ? int.tryParse(slotMatch.group(1)!) ?? 20 : 20;
      final maxAllowed = (totalSlots * 0.20).floor();
      final barredMin = maxAllowed + 1;

      final lines = context.split('\n');
      final barredLines = <String>[];
      final dangerLines = <String>[];
      int mode = 0; // 1: barred, 2: danger

      for (final line in lines) {
        if (line.contains('DANH SÁCH SINH VIÊN BỊ CẤM THI')) {
          mode = 1;
          continue;
        } else if (line.contains('DANH SÁCH SINH VIÊN NGUY CƠ CẤM THI')) {
          mode = 2;
          continue;
        } else if (line.startsWith('---') || line.startsWith('===')) {
          mode = 0;
          continue;
        }

        if (mode == 1 && line.trim().isNotEmpty) {
          barredLines.add(line.trim());
        } else if (mode == 2 && line.trim().isNotEmpty) {
          dangerLines.add(line.trim());
        }
      }

      final buffer = StringBuffer();
      buffer.writeln('🚨 **CẢNH BÁO HỌC VỤ & NGUY CƠ CẤM THI (QUY CHẾ FPTU)**\n');
      buffer.writeln('📋 *Căn cứ quy chế đào tạo:* Môn học có tổng cộng **$totalSlots slots**. '
          'Sinh viên được phép vắng tối đa **$maxAllowed slots (≤ 20%)**. '
          'Chỉ khi vắng **từ $barredMin slots trở lên (> 20%)** mới **BỊ CẤM THI**.\n'
          '*Mỗi sinh viên được định danh duy nhất bằng Email FPT.*\n');

      if (barredLines.isNotEmpty) {
        buffer.writeln('🚫 **NHÓM BỊ CẤM THI (Vắng quá 20% tổng số slot):**');
        for (final l in barredLines) {
          buffer.writeln('• $l');
        }
      } else {
        buffer.writeln('✅ **NHÓM BỊ CẤM THI:** Hiện tại chưa có sinh viên nào vắng quá 20% (trên $maxAllowed slot).');
      }

      buffer.writeln('');

      if (dangerLines.isNotEmpty) {
        buffer.writeln('⚠️ **NHÓM NGUY CƠ CẤM THI (Vắng gần hoặc chạm 20%):**');
        for (final l in dangerLines) {
          buffer.writeln('• $l');
        }
      } else {
        buffer.writeln('👍 **NHÓM NGUY CƠ CẤM THI:** Không có sinh viên nào tiệm cận ngưỡng cấm thi.');
      }

      buffer.writeln('\n💡 **Khuyến nghị cho giảng viên:**');
      buffer.writeln('- Gửi Email học vụ nhắc nhở trực tiếp đến các sinh viên trong nhóm **Nguy cơ cấm thi** để các bạn không nghỉ thêm buổi nào.');
      buffer.writeln('- Đối với sinh viên đã vượt ngưỡng cấm thi, chuyển danh sách cho Cán bộ Đào tạo xác nhận danh sách thi cuối kỳ.');

      return buffer.toString();
    }

    // 2. Tra cứu danh sách sinh viên vắng ở buổi hiện tại
    if (lowerPrompt.contains('vắng') || lowerPrompt.contains('ai chưa') || lowerPrompt.contains('chưa điểm danh')) {
      if (!context.contains('DANH SÁCH SINH VIÊN VẮNG HOẶC CHƯA ĐIỂM DANH')) {
        return '🎉 Tuyệt vời! Hiện tại không có sinh viên nào vắng mặt trong buổi học này (100% sinh viên đã điểm danh).';
      }
      final lines = context.split('\n');
      final absentLines = <String>[];
      bool recording = false;
      for (final line in lines) {
        if (line.contains('DANH SÁCH SINH VIÊN VẮNG HOẶC CHƯA ĐIỂM DANH')) {
          recording = true;
          continue;
        }
        if (recording && line.startsWith('---')) break;
        if (recording && line.trim().isNotEmpty) {
          absentLines.add(line);
        }
      }
      return '📋 **Danh sách sinh viên hiện đang vắng / chưa điểm danh ở buổi hiện tại:**\n\n'
          '${absentLines.join('\n')}\n\n'
          '💡 *Khuyến nghị:* Giảng viên có thể nhắc nhở các bạn trước khi chính thức chốt đóng phiên.';
    }

    // 3. Tỷ lệ chuyên cần buổi học
    if (lowerPrompt.contains('tỷ lệ') || lowerPrompt.contains('chuyên cần') || lowerPrompt.contains('phần trăm') || lowerPrompt.contains('%')) {
      final match = RegExp(r'Có MẶT:\s*(\d+)\s*sinh viên\s*\(([\d\.]+%)\)', caseSensitive: false).firstMatch(context);
      if (match != null) {
        final count = match.group(1);
        final rate = match.group(2);
        return '📊 **Thống kê chuyên cần buổi học hôm nay:**\n\n'
            '• **Số sinh viên có mặt:** $count bạn\n'
            '• **Tỷ lệ chuyên cần đạt:** **$rate**\n\n'
            '${double.tryParse(rate?.replaceAll('%', '') ?? '0')! >= 80 ? "✅ Lớp đạt tỷ lệ chuyên cần rất tốt!" : "⚠️ Tỷ lệ chuyên cần còn thấp, cần kiểm tra sĩ số lớp."}';
      }
      return 'Hiện tại chưa đủ số liệu để tính tỷ lệ chuyên cần. Vui lòng mở hoặc chọn một phiên học.';
    }

    // 4. Gian lận / Trùng lặp
    if (lowerPrompt.contains('trùng') || lowerPrompt.contains('gian lận') || lowerPrompt.contains('nghi vấn')) {
      if (context.contains('CẢNH BÁO NỘP TRÙNG LẶP')) {
        final lines = context.split('\n');
        final warningLines = <String>[];
        bool recording = false;
        for (final line in lines) {
          if (line.contains('CẢNH BÁO NỘP TRÙNG LẶP')) {
            recording = true;
            continue;
          }
          if (recording && line.startsWith('---')) break;
          if (recording && line.trim().isNotEmpty) {
            warningLines.add(line);
          }
        }
        return '⚠️ **Phát hiện các trường hợp nộp trùng / nghi vấn:**\n\n'
            '${warningLines.join('\n')}\n\n'
            '🛡️ *Hệ thống đã tự động chặn các lượt gửi sau và chỉ bảo lưu 1 lượt nộp hợp lệ đầu tiên của sinh viên.*';
      }
      return '🛡️ Hệ thống kiểm tra an toàn: **Không phát hiện trường hợp nộp trùng lặp hay vé quá hạn nào** trong phiên học này.';
    }

    // 5. Tóm tắt / Báo cáo
    if (lowerPrompt.contains('tóm tắt') || lowerPrompt.contains('tổng quan') || lowerPrompt.contains('báo cáo')) {
      return '📝 **Tóm tắt nhanh tình hình buổi học:**\n\n'
          'Hệ thống ghi nhận phiên học đang diễn ra bình thường. Các mã vé QR được cấp phát tự động mỗi 30 giây.\n'
          'Bạn có thể bấm nút **"Tạo báo cáo chuyên cần"** ở thanh công cụ phía trên để xem văn bản báo cáo chi tiết đầy đủ.';
    }

    return '**Trợ lý Chuyên cần & Học vụ:**\n\n'
        'Hệ thống đã tiếp nhận câu hỏi. Dựa trên dữ liệu ca học hiện tại:\n'
        '• Kiểm tra nguy cơ cấm thi: *"Sinh viên nào vắng gần 20% hoặc bị cấm thi?"*\n'
        '• Tra cứu điểm danh hôm nay: *"Ai chưa điểm danh trong buổi học này?"*\n'
        '• Thống kê tỷ lệ chuyên cần: *"Tỷ lệ chuyên cần hôm nay thế nào?"*\n'
        '• Kiểm tra gian lận: *"Có lượt nộp trùng lặp nào không?"*';
  }

  @override
  Future<String> generateReport({
    required AttendanceSummary summary,
    List<SessionDayGroup>? history,
    ClassModel? classModel,
    String? apiKey,
    List<String>? apiKeys,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final scope = summary.scope;
    final rate = summary.totalStudents > 0
        ? ((summary.presentCount / summary.totalStudents) * 100).toStringAsFixed(1)
        : '0.0';
    final nowFormatted = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    final totalSlots = classModel?.totalSlots ?? 20;
    final maxAllowed = (totalSlots * 0.20).floor();
    final barredMin = maxAllowed + 1;
    final absenceRecords = CourseAbsenceTracker.analyzeClassAbsences(
      currentSummary: summary,
      classModel: classModel,
      totalSlots: totalSlots,
    );
    final barredStudents = absenceRecords.where((r) => r.isBarred).toList();
    final dangerStudents = absenceRecords.where((r) => r.isNearDanger).toList();

    final buffer = StringBuffer();
    buffer.writeln('# BÁO CÁO CHUYÊN CẦN BUỔI HỌC');
    buffer.writeln('*Hệ thống Điểm danh QR Thông minh - Xuất lúc: $nowFormatted*\n');
    buffer.writeln('---');
    buffer.writeln('### 1. Thông tin phiên học');
    buffer.writeln('- **Môn học:** ${scope.className}');
    buffer.writeln('- **Thời gian:** Ngày ${scope.date} | Slot ${scope.slotNumber} (${scope.timeRange})');
    buffer.writeln('- **Trạng thái:** ${summary.isFinalized ? "✅ Đã đóng phiên & chốt sổ" : "⏳ Phiên đang mở (Số liệu tạm tính)"}');
    buffer.writeln('');
    buffer.writeln('### 2. Thống kê số liệu chuyên cần');
    buffer.writeln('| Chỉ số | Số lượng | Tỷ lệ |');
    buffer.writeln('| :--- | :---: | :---: |');
    buffer.writeln('| **Tổng sĩ số lớp** | ${summary.totalStudents} | 100% |');
    buffer.writeln('| **Có mặt (Present)** | ${summary.presentCount} | **$rate%** |');
    buffer.writeln('| **Vắng mặt (Absent / Chưa điểm danh)** | ${summary.pendingCount} | ${(100.0 - (double.tryParse(rate) ?? 0.0)).toStringAsFixed(1)}% |');
    buffer.writeln('| **Cảnh báo nộp trùng (Retries)** | ${summary.retryEventCount} | - |');
    buffer.writeln('');

    buffer.writeln('### 3. Đánh giá của AI');
    final doubleRate = double.tryParse(rate) ?? 0.0;
    if (doubleRate >= 90) {
      buffer.writeln('🌟 **Xuất sắc:** Lớp học đạt tỷ lệ chuyên cần rất cao ($rate%). Sinh viên tham gia đầy đủ và nghiêm túc.');
    } else if (doubleRate >= 75) {
      buffer.writeln('👍 **Đạt yêu cầu:** Tỷ lệ chuyên cần ở mức khá ($rate%). Đa số sinh viên có mặt đúng giờ.');
    } else {
      buffer.writeln('⚠️ **Cần lưu ý:** Tỷ lệ chuyên cần thấp ($rate%). Có ${summary.pendingCount} sinh viên vắng mặt.');
    }
    buffer.writeln('');

    buffer.writeln('### 4. Cảnh báo Học vụ & Nguy cơ Cấm thi (Quy chế vắng quá 20% tổng số slot)');
    buffer.writeln('Theo quy chế đào tạo, môn học có **$totalSlots slots**, sinh viên được phép vắng tối đa **$maxAllowed slots (≤ 20%)**. '
        'Chỉ khi vắng từ **$barredMin slots trở lên (> 20%)** mới bị cấm thi. Mỗi sinh viên được xác nhận bằng **Email định danh duy nhất**:\n');

    if (barredStudents.isNotEmpty) {
      buffer.writeln('**🚫 Danh sách sinh viên BỊ CẤM THI (Vắng quá 20%):**');
      for (var i = 0; i < barredStudents.length; i++) {
        final s = barredStudents[i];
        buffer.writeln('${i + 1}. **${s.studentName}** - Email: `${s.email}` - Vắng: **${s.totalAbsentSlots}/$totalSlots slot** (${s.absenceRate.toStringAsFixed(1)}%)');
      }
    } else {
      buffer.writeln('✅ Hiện tại chưa có sinh viên nào vắng quá 20% (vượt quá $maxAllowed slot).');
    }
    buffer.writeln('');

    if (dangerStudents.isNotEmpty) {
      buffer.writeln('**⚠️ Danh sách sinh viên NGUY CƠ CẤM THI (Vắng gần hoặc chạm 20%):**');
      for (var i = 0; i < dangerStudents.length; i++) {
        final s = dangerStudents[i];
        buffer.writeln('${i + 1}. **${s.studentName}** - Email: `${s.email}` - Vắng: **${s.totalAbsentSlots}/$totalSlots slot** (${s.absenceRate.toStringAsFixed(1)}%) - *Còn được phép nghỉ: ${s.remainingAllowedSlots} buổi*');
      }
    } else {
      buffer.writeln('👍 Không có sinh viên nào ở vùng nguy cơ tiệm cận ngưỡng cấm thi.');
    }
    buffer.writeln('');

    final absentRows = summary.rows.where((r) => r.status != StudentAttendanceStatus.present).toList();
    if (absentRows.isNotEmpty) {
      buffer.writeln('### 5. Danh sách sinh viên vắng mặt ở buổi hiện tại');
      for (var i = 0; i < absentRows.length; i++) {
        final r = absentRows[i];
        buffer.writeln('${i + 1}. **${r.student.displayName}** - Email: `${r.student.email}`');
      }
      buffer.writeln('');
    }

    if (summary.retryEvents.isNotEmpty) {
      buffer.writeln('### 6. Cảnh báo nộp trùng / Gian lận');
      buffer.writeln('Hệ thống ghi nhận **${summary.retryEvents.length} lượt nộp lặp lại** từ sinh viên:');
      for (final evt in summary.retryEvents) {
        buffer.writeln('- ${evt.displayName} (Lý do: ${evt.attempt.attemptType})');
      }
      buffer.writeln('');
    }

    buffer.writeln('---');
    buffer.writeln('*Báo cáo được khởi tạo tự động bởi Trợ lý AI Điểm danh.*');
    return buffer.toString();
  }
}
