import 'package:flutter/material.dart';
import 'package:flutter_qr_attendance/core/storage/ai_usage_storage.dart';
import 'package:flutter_qr_attendance/data/services/ai_usage_tracker.dart';
import 'package:flutter_qr_attendance/data/services/attendance_service.dart';
import 'package:flutter_qr_attendance/data/services/gemini_ai_service.dart';
import 'package:flutter_qr_attendance/data/services/gemini_key_rotator.dart';
import 'package:flutter_qr_attendance/features/ai_assistant/ai_assistant_provider.dart';
import 'package:flutter_qr_attendance/features/ai_assistant/ai_assistant_view.dart';
import 'package:flutter_qr_attendance/features/ai_assistant/widgets/ai_usage_dashboard_dialog.dart';
import 'package:flutter_qr_attendance/features/attendance/attendance_history_provider.dart';
import 'package:flutter_qr_attendance/features/attendance/attendance_results_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('vi_VN', null);
  });

  Widget buildTestDialog({required AiAssistantProvider provider}) {
    return ChangeNotifierProvider.value(
      value: provider,
      child: const MaterialApp(home: Scaffold(body: AiUsageDashboardDialog())),
    );
  }

  group('AiUsageDashboardDialog Widget Tests', () {
    testWidgets('hiển thị đúng giao diện rỗng khi chưa có lượt gọi AI nào', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final storage = MemoryAiUsageStorage();
      final tracker = AiUsageTracker(storage: storage);
      await tracker.initialize();

      final rotator = GeminiKeyRotator();
      final provider = AiAssistantProvider(
        aiService: LocalAttendanceAiService(),
        rotator: rotator,
        usageTracker: tracker,
      );

      await tester.pumpWidget(buildTestDialog(provider: provider));
      await tester.pumpAndSettle();

      // Kiểm tra Header
      expect(find.text('Giám sát AI & Kiểm soát Chi phí'), findsOneWidget);
      expect(find.textContaining('Google Gemini 2.5 Flash'), findsOneWidget);

      // Kiểm tra 4 Thẻ Summary Cards
      expect(find.text('Tổng số yêu cầu'), findsOneWidget);
      expect(find.text('Lượng Token'), findsOneWidget);
      expect(find.text('Chi phí ước tính'), findsOneWidget);
      expect(find.text('Độ trễ trung bình'), findsOneWidget);
      expect(find.text('Chưa có yêu cầu nào'), findsOneWidget);

      // Kiểm tra Pool trạng thái key rỗng
      expect(
        find.text('Tình trạng Pool API Keys (0/0 khả dụng)'),
        findsOneWidget,
      );
      expect(find.textContaining('Local Analytical Engine'), findsOneWidget);

      // Kiểm tra Empty State của bảng nhật ký
      expect(find.text('Chưa có dữ liệu gọi AI nào'), findsOneWidget);

      // Kiểm tra các nút hành động
      expect(find.text('Xóa lịch sử thống kê'), findsOneWidget);
      expect(find.text('Đóng'), findsOneWidget);
    });

    testWidgets(
      'hiển thị chính xác số liệu thống kê tổng hợp và danh sách khi có dữ liệu ghi nhận',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final storage = MemoryAiUsageStorage();
        final tracker = AiUsageTracker(storage: storage);
        await tracker.initialize();

        // Ghi nhận 2 bản ghi AI
        await tracker.record(
          operation: 'chat',
          model: 'gemini-2.5-flash',
          promptTokens: 500,
          candidatesTokens: 150,
          latencyMs: 1200,
          keyMasked: 'AIzaSy...4xK9',
          isSuccess: true,
        );

        await tracker.record(
          operation: 'report',
          model: 'gemini-2.5-flash',
          promptTokens: 1000,
          candidatesTokens: 400,
          latencyMs: 2500,
          keyMasked: 'AIzaSy...9xZ1',
          isSuccess: true,
        );

        final rotator = GeminiKeyRotator([
          'AIzaSyAlpha12345678',
          'AIzaSyBeta9876543210',
        ]);
        rotator.recordSuccess('AIzaSyAlpha12345678');
        rotator.rotateOnFailure(
          'AIzaSyBeta9876543210',
          reason: 'Rate limit (429)',
          isRateLimit: true,
        );

        final provider = AiAssistantProvider(
          aiService: LocalAttendanceAiService(),
          rotator: rotator,
          usageTracker: tracker,
        );

        await tester.pumpWidget(buildTestDialog(provider: provider));
        await tester.pumpAndSettle();

        // Kiểm tra thẻ Summary
        expect(find.text('2'), findsOneWidget); // 2 total requests
        expect(
          find.text('2,050'),
          findsOneWidget,
        ); // 500+150+1000+400 = 2,050 tokens
        expect(find.textContaining('100.0% thành công'), findsOneWidget);

        // Kiểm tra tình trạng Key Pool
        expect(
          find.text('Tình trạng Pool API Keys (1/2 khả dụng)'),
          findsOneWidget,
        );
        expect(find.text('Hoạt động'), findsOneWidget);
        expect(find.text('Chạm giới hạn (429)'), findsOneWidget);

        // Kiểm tra danh sách nhật ký
        expect(find.text('Trò chuyện AI'), findsOneWidget);
        expect(find.text('Tạo Báo cáo'), findsOneWidget);
        expect(
          find.textContaining('Tokens: 500 in + 150 out = 650 tổng'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Tokens: 1000 in + 400 out = 1400 tổng'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'lọc danh sách lượt gọi theo loại thao tác (Tất cả, Chat, Báo cáo)',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final storage = MemoryAiUsageStorage();
        final tracker = AiUsageTracker(storage: storage);
        await tracker.initialize();

        await tracker.record(
          operation: 'chat',
          model: 'gemini-2.5-flash',
          promptTokens: 400,
          candidatesTokens: 100,
          latencyMs: 1000,
          keyMasked: 'AIzaSy...4xK9',
          isSuccess: true,
        );

        await tracker.record(
          operation: 'report',
          model: 'gemini-2.5-flash',
          promptTokens: 800,
          candidatesTokens: 300,
          latencyMs: 2000,
          keyMasked: 'AIzaSy...9xZ1',
          isSuccess: true,
        );

        final provider = AiAssistantProvider(
          aiService: LocalAttendanceAiService(),
          usageTracker: tracker,
        );

        await tester.pumpWidget(buildTestDialog(provider: provider));
        await tester.pumpAndSettle();

        // Ban đầu hiển thị cả 2 bản ghi
        expect(find.text('Trò chuyện AI'), findsOneWidget);
        expect(find.text('Tạo Báo cáo'), findsOneWidget);

        // Chạm vào filter "Chat (1)"
        await tester.tap(find.text('Chat (1)'));
        await tester.pumpAndSettle();

        expect(find.text('Trò chuyện AI'), findsOneWidget);
        expect(find.text('Tạo Báo cáo'), findsNothing);

        // Chạm vào filter "Báo cáo (1)"
        await tester.tap(find.text('Báo cáo (1)'));
        await tester.pumpAndSettle();

        expect(find.text('Trò chuyện AI'), findsNothing);
        expect(find.text('Tạo Báo cáo'), findsOneWidget);

        // Chạm lại filter "Tất cả (2)"
        await tester.tap(find.text('Tất cả (2)'));
        await tester.pumpAndSettle();

        expect(find.text('Trò chuyện AI'), findsOneWidget);
        expect(find.text('Tạo Báo cáo'), findsOneWidget);
      },
    );

    testWidgets(
      'khôi phục sức khỏe Key Pool khi bấm nút Khôi phục sức khỏe Keys',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final storage = MemoryAiUsageStorage();
        final tracker = AiUsageTracker(storage: storage);
        await tracker.initialize();

        final rotator = GeminiKeyRotator(['AIzaSyTestKey123456']);
        rotator.rotateOnFailure(
          'AIzaSyTestKey123456',
          reason: '429 Rate limit',
          isRateLimit: true,
        );
        expect(rotator.activeKeyCount, 0);

        final provider = AiAssistantProvider(
          aiService: LocalAttendanceAiService(),
          rotator: rotator,
          usageTracker: tracker,
        );

        await tester.pumpWidget(buildTestDialog(provider: provider));
        await tester.pumpAndSettle();

        expect(
          find.text('Tình trạng Pool API Keys (0/1 khả dụng)'),
          findsOneWidget,
        );
        expect(find.text('Chạm giới hạn (429)'), findsOneWidget);

        // Bấm nút Khôi phục sức khỏe Keys
        final resetBtn = find.text('Khôi phục sức khỏe Keys');
        expect(resetBtn, findsOneWidget);
        await tester.tap(resetBtn);
        await tester.pumpAndSettle();

        expect(rotator.activeKeyCount, 1);
        expect(
          find.text('Tình trạng Pool API Keys (1/1 khả dụng)'),
          findsOneWidget,
        );
        expect(find.text('Hoạt động'), findsOneWidget);
      },
    );

    testWidgets('hộp thoại xác nhận xóa lịch sử hoạt động chính xác', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final storage = MemoryAiUsageStorage();
      final tracker = AiUsageTracker(storage: storage);
      await tracker.initialize();

      await tracker.record(
        operation: 'chat',
        model: 'gemini-2.5-flash',
        promptTokens: 400,
        candidatesTokens: 100,
        latencyMs: 1000,
        keyMasked: 'AIzaSy...4xK9',
        isSuccess: true,
      );
      expect(tracker.records.length, 1);

      final provider = AiAssistantProvider(
        aiService: LocalAttendanceAiService(),
        usageTracker: tracker,
      );

      await tester.pumpWidget(buildTestDialog(provider: provider));
      await tester.pumpAndSettle();

      // Bấm nút Xóa lịch sử thống kê
      await tester.tap(find.text('Xóa lịch sử thống kê'));
      await tester.pumpAndSettle();

      // Hộp thoại xác nhận xuất hiện
      expect(find.text('Xác nhận đặt lại thống kê'), findsOneWidget);

      // Bấm Hủy bỏ
      await tester.tap(find.text('Hủy bỏ'));
      await tester.pumpAndSettle();

      // Bản ghi vẫn còn
      expect(tracker.records.length, 1);
      expect(find.text('Trò chuyện AI'), findsOneWidget);

      // Bấm lại Xóa và bấm xác nhận Xóa lịch sử
      await tester.tap(find.text('Xóa lịch sử thống kê'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Xóa lịch sử'));
      await tester.pumpAndSettle();

      // Lịch sử đã bị xóa sạch
      expect(tracker.records.isEmpty, isTrue);
      expect(find.text('Chưa có dữ liệu gọi AI nào'), findsOneWidget);
    });

    testWidgets(
      'từ AiAssistantView bấm nút Thống kê AI mở thành công dialog Dashboard',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final mockService = MockAttendanceService(simulateDelay: false);
        final resultsProvider = AttendanceResultsProvider(service: mockService);
        final historyProvider = AttendanceHistoryProvider(service: mockService);
        final storage = MemoryAiUsageStorage();
        final tracker = AiUsageTracker(storage: storage);
        await tracker.initialize();

        final aiProvider = AiAssistantProvider(
          aiService: LocalAttendanceAiService(),
          usageTracker: tracker,
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: resultsProvider),
              ChangeNotifierProvider.value(value: historyProvider),
              ChangeNotifierProvider.value(value: aiProvider),
            ],
            child: const MaterialApp(home: Scaffold(body: AiAssistantView())),
          ),
        );
        await tester.pumpAndSettle();

        // Nút Thống kê AI hiển thị trên toolbar
        final dashboardBtn = find.text('Thống kê AI');
        expect(dashboardBtn, findsOneWidget);

        // Bấm nút để mở dialog
        await tester.tap(dashboardBtn);
        await tester.pumpAndSettle();

        // Dialog Dashboard đã mở
        expect(find.byType(AiUsageDashboardDialog), findsOneWidget);
        expect(find.text('Giám sát AI & Kiểm soát Chi phí'), findsOneWidget);
        expect(
          find.text('Tình trạng Pool API Keys (0/0 khả dụng)'),
          findsOneWidget,
        );

        // Bấm nút Đóng
        await tester.tap(find.text('Đóng'));
        await tester.pumpAndSettle();

        // Dialog đã đóng
        expect(find.byType(AiUsageDashboardDialog), findsNothing);
      },
    );

    testWidgets(
      'tìm kiếm theo từ khóa và lọc theo trạng thái thành công / thất bại',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final storage = MemoryAiUsageStorage();
        final tracker = AiUsageTracker(storage: storage);
        await tracker.initialize();

        // Bản ghi 1: Thành công
        await tracker.record(
          operation: 'chat',
          model: 'gemini-2.5-flash',
          promptTokens: 400,
          candidatesTokens: 100,
          latencyMs: 1200,
          keyMasked: 'AIzaSy...4xK9',
          isSuccess: true,
        );

        // Bản ghi 2: Thất bại do 429
        await tracker.record(
          operation: 'chat',
          model: 'gemini-2.5-flash',
          promptTokens: 0,
          candidatesTokens: 0,
          latencyMs: 150,
          keyMasked: 'AIzaSy...8xZ2',
          isSuccess: false,
          errorMessage: 'Rate limit (429) quota exceeded',
        );

        final provider = AiAssistantProvider(
          aiService: LocalAttendanceAiService(),
          usageTracker: tracker,
        );

        await tester.pumpWidget(buildTestDialog(provider: provider));
        await tester.pumpAndSettle();

        // Ban đầu hiển thị cả 2 bản ghi
        expect(find.text('Trò chuyện AI'), findsNWidgets(2));
        expect(find.textContaining('Lỗi: Rate limit (429) quota exceeded'), findsOneWidget);

        // Lọc chỉ xem lỗi: '✕ Lỗi (1)'
        await tester.tap(find.text('✕ Lỗi (1)'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Lỗi: Rate limit (429) quota exceeded'), findsOneWidget);
        expect(find.textContaining('400 in + 100 out'), findsNothing);

        // Lọc chỉ xem thành công: '✓ Thành công (1)'
        await tester.tap(find.text('✓ Thành công (1)'));
        await tester.pumpAndSettle();

        expect(find.textContaining('400 in + 100 out'), findsOneWidget);
        expect(find.textContaining('Lỗi: Rate limit'), findsNothing);

        // Quay lại 'Tất cả trạng thái'
        await tester.tap(find.text('Tất cả'));
        await tester.pumpAndSettle();

        // Tìm kiếm theo từ khóa '429'
        final searchField = find.byType(TextField);
        expect(searchField, findsOneWidget);
        await tester.enterText(searchField, '429');
        await tester.pumpAndSettle();

        expect(find.textContaining('Lỗi: Rate limit (429) quota exceeded'), findsOneWidget);
        expect(find.textContaining('400 in + 100 out'), findsNothing);

        // Xóa tìm kiếm bằng nút (x)
        await tester.tap(find.byIcon(Icons.clear));
        await tester.pumpAndSettle();

        expect(find.text('Trò chuyện AI'), findsNWidgets(2));
      },
    );

    testWidgets(
      'chạm vào bản ghi để mở rộng xem chi tiết và kiểm tra nút sao chép tóm tắt',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final storage = MemoryAiUsageStorage();
        final tracker = AiUsageTracker(storage: storage);
        await tracker.initialize();

        await tracker.record(
          operation: 'report',
          model: 'gemini-2.5-flash',
          promptTokens: 1200,
          candidatesTokens: 600,
          latencyMs: 3100,
          keyMasked: 'AIzaSy...7yP3',
          isSuccess: true,
        );

        final provider = AiAssistantProvider(
          aiService: LocalAttendanceAiService(),
          usageTracker: tracker,
        );

        await tester.pumpWidget(buildTestDialog(provider: provider));
        await tester.pumpAndSettle();

        // Ban đầu chưa mở rộng
        expect(find.text('Chi tiết bản ghi tương tác:'), findsNothing);

        // Chạm vào dòng bản ghi để mở rộng
        await tester.tap(find.text('Tạo Báo cáo'));
        await tester.pumpAndSettle();

        // Đã mở rộng chi tiết
        expect(find.text('Chi tiết bản ghi tương tác:'), findsOneWidget);
        expect(find.textContaining('Prompt Token: 1200'), findsOneWidget);
        expect(find.textContaining('Candidate Token: 600'), findsOneWidget);

        // Kiểm tra nút Sao chép tóm tắt
        final copyBtn = find.text('Sao chép tóm tắt');
        expect(copyBtn, findsOneWidget);
        await tester.tap(copyBtn);
        await tester.pumpAndSettle();

        expect(find.text('Đã sao chép tóm tắt thống kê AI vào bộ nhớ tạm!'), findsOneWidget);
      },
    );
  });
}
