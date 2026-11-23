import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/travel_group_chat_page.dart';

void main() {
  const testGroup = TravelGroup(
    id: 99,
    name: 'Đoàn Du Lịch Đà Nẵng - Hội An 2026',
    inviteCode: 'VIETQR88',
    itineraryId: 101,
  );

  Widget createChatWidget({
    TravelGroup? group,
    int userId = 1,
    String userName = 'Bạn',
  }) {
    return MaterialApp(
      home: TravelGroupChatPage(
        groupId: 99,
        group: group ?? testGroup,
        currentUserId: userId,
        currentUserName: userName,
      ),
    );
  }

  void configureViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
  }

  group('Travel Group Mobile - End-to-End Workflow & Exception Safety Tests', () {
    testWidgets(
      'Workflow 1: Tour Guide Announcement & Roll Call Full Lifecycle',
      (tester) async {
        configureViewport(tester);
        await tester.pumpWidget(createChatWidget());
        await tester.pumpAndSettle();

        // Verify Header & Pinned announcement
        expect(find.text('Đoàn Du Lịch Đà Nẵng - Hội An 2026'), findsOneWidget);
        expect(
          find.textContaining('Ghim: Tập trung lúc 07:30'),
          findsOneWidget,
        );

        // 1. Dismiss pinned announcement
        expect(find.byKey(const Key('dismiss_pinned_button')), findsOneWidget);
        await tester.tap(find.byKey(const Key('dismiss_pinned_button')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('dismiss_pinned_button')), findsNothing);

        // 2. Tour Guide Broadcast Card acknowledgment
        expect(find.text('THÔNG BÁO TẬP TRUNG SÁNG MAI'), findsOneWidget);
        expect(find.text('QUAN TRỌNG'), findsOneWidget);
        expect(find.text('3/4 đã đọc'), findsOneWidget);

        final ackBtn = find.byKey(const Key('broadcast_ack_msg-2'));
        expect(ackBtn, findsOneWidget);
        await tester.tap(ackBtn);
        await tester.pumpAndSettle();

        expect(find.text('4/4 đã đọc'), findsOneWidget);
        expect(find.text('Đã đọc'), findsOneWidget);
        expect(
          find.text('Bạn đã xác nhận đã đọc thông báo này.'),
          findsOneWidget,
        );

        // 3. Roll Call attendance check-in
        expect(find.text('Điểm danh: Tập trung xe buýt số 1'), findsOneWidget);
        expect(find.text('Có mặt: 3/4 thành viên'), findsOneWidget);

        final rollCallBtn = find.byKey(const Key('roll_call_button_msg-3'));
        expect(rollCallBtn, findsOneWidget);
        await tester.tap(rollCallBtn);
        await tester.pumpAndSettle();

        expect(find.text('Có mặt: 4/4 thành viên'), findsOneWidget);
        expect(find.text('Đã có mặt'), findsOneWidget);
        expect(find.text('Xác nhận điểm danh thành công!'), findsOneWidget);

        // 4. Idempotent double-tap check on Broadcast & Roll Call (never increments to 5/4)
        await tester.tap(ackBtn);
        await tester.pumpAndSettle();
        expect(find.text('4/4 đã đọc'), findsOneWidget);

        await tester.tap(rollCallBtn);
        await tester.pumpAndSettle();
        expect(find.text('Có mặt: 4/4 thành viên'), findsOneWidget);
      },
    );

    testWidgets('Workflow 2: Expense Splitting, VietQR Modal & Payment Toggle', (
      tester,
    ) async {
      configureViewport(tester);
      await tester.pumpWidget(createChatWidget());
      await tester.pumpAndSettle();

      // Open Action Drawer
      final drawerBtn = find.byKey(const Key('open_action_drawer_button'));
      await tester.tap(drawerBtn);
      await tester.pumpAndSettle();

      // Tap "Chia tiền hóa đơn (VietQR)"
      final expenseAction = find.byKey(const Key('action_create_expense'));
      expect(expenseAction, findsOneWidget);
      await tester.tap(expenseAction);
      await tester.pumpAndSettle();

      expect(find.text('Chia tiền chi tiêu (VietQR)'), findsOneWidget);

      // Boundary validation test: Submit empty form
      final submitExpenseBtn = find.byKey(const Key('submit_expense_button'));
      await tester.tap(submitExpenseBtn);
      await tester.pumpAndSettle();

      expect(
        find.text('Vui lòng nhập nội dung và số tiền hợp lệ (> 0).'),
        findsOneWidget,
      );

      // Fill in valid expense
      await tester.enterText(
        find.byKey(const Key('expense_title_input')),
        'Tiền thuê tàu cano đi Cù Lao Chàm',
      );
      await tester.enterText(
        find.byKey(const Key('expense_amount_input')),
        '800000',
      );
      await tester.tap(submitExpenseBtn);
      await tester.pumpAndSettle();

      // Verify Split Bill Card is rendered in chat
      expect(find.text('Tiền thuê tàu cano đi Cù Lao Chàm'), findsOneWidget);
      expect(find.text('800.000 đ'), findsOneWidget);
      expect(find.text('200.000 đ'), findsOneWidget); // 800k / 4 = 200k

      // Open VietQR modal for existing bill msg-6
      final openQrBtn = find.byKey(const Key('open_vietqr_button_msg-6'));
      await tester.tap(openQrBtn);
      await tester.pumpAndSettle();

      expect(find.text('Thanh toán qua VietQR'), findsOneWidget);
      expect(find.text('MB Bank'), findsOneWidget);
      expect(find.text('0987654321'), findsOneWidget);
      expect(find.text('LE THI HUONG'), findsOneWidget);

      // Toggle paid status
      final togglePaidBtn = find.byKey(const Key('toggle_paid_button'));
      await tester.tap(togglePaidBtn);
      await tester.pumpAndSettle();

      // Modal closed and status updated (both new bill and msg-6 are now paid by user 1)
      expect(find.text('Đã trả • VietQR'), findsNWidgets(2));
    });

    testWidgets('Workflow 3: Poll Creation, Multi-Option Voting & Retraction', (
      tester,
    ) async {
      configureViewport(tester);
      await tester.pumpWidget(createChatWidget());
      await tester.pumpAndSettle();

      // Open Action Drawer
      await tester.tap(find.byKey(const Key('open_action_drawer_button')));
      await tester.pumpAndSettle();

      // Tap "Tạo bình chọn"
      await tester.tap(find.byKey(const Key('action_create_poll')));
      await tester.pumpAndSettle();

      expect(find.text('Tạo bình chọn mới'), findsOneWidget);

      // Boundary validation test: Empty question
      await tester.tap(find.byKey(const Key('submit_poll_button')));
      await tester.pumpAndSettle();
      expect(
        find.text('Vui lòng nhập câu hỏi và ít nhất 2 lựa chọn.'),
        findsOneWidget,
      );

      // Fill in valid poll
      await tester.enterText(
        find.byKey(const Key('poll_question_input')),
        'Chọn điểm ngắm hoàng hôn Hội An?',
      );
      await tester.enterText(
        find.byKey(const Key('poll_option_1_input')),
        'Cà phê Roving Chillhouse',
      );
      await tester.enterText(
        find.byKey(const Key('poll_option_2_input')),
        'Chèo SUP trên sông Thu Bồn',
      );
      await tester.enterText(
        find.byKey(const Key('poll_option_3_input')),
        'Bãi biển An Bàng',
      );

      await tester.tap(find.byKey(const Key('submit_poll_button')));
      await tester.pumpAndSettle();

      // Verify poll is rendered
      expect(find.text('Chọn điểm ngắm hoàng hôn Hội An?'), findsOneWidget);
      expect(find.text('Cà phê Roving Chillhouse'), findsOneWidget);
      expect(find.text('Chèo SUP trên sông Thu Bồn'), findsOneWidget);
      expect(find.text('Bãi biển An Bàng'), findsOneWidget);

      // Vote on option 0 of poll msg-7
      final pollOpt0 = find.byKey(const Key('poll_option_msg-7_0'));
      await tester.tap(pollOpt0);
      await tester.pumpAndSettle();
      expect(find.text('3 phiếu'), findsOneWidget);

      // Retract vote by tapping again
      await tester.tap(pollOpt0);
      await tester.pumpAndSettle();
      expect(find.text('2 phiếu'), findsOneWidget);
    });

    testWidgets('Workflow 4: Tour Guide Broadcast Creation via Drawer', (
      tester,
    ) async {
      configureViewport(tester);
      await tester.pumpWidget(createChatWidget());
      await tester.pumpAndSettle();

      // Open Action Drawer
      await tester.tap(find.byKey(const Key('open_action_drawer_button')));
      await tester.pumpAndSettle();

      // Tap Broadcast option
      await tester.tap(find.byKey(const Key('action_create_broadcast')));
      await tester.pumpAndSettle();

      expect(find.text('Gửi thông báo khẩn (HDV)'), findsOneWidget);

      // Boundary validation: Submit empty
      await tester.tap(find.byKey(const Key('submit_broadcast_button')));
      await tester.pumpAndSettle();
      expect(
        find.text('Vui lòng nhập đầy đủ tiêu đề và nội dung thông báo.'),
        findsOneWidget,
      );

      // Fill in broadcast
      await tester.enterText(
        find.byKey(const Key('broadcast_title_input')),
        'ĐỔI GIỜ XUẤT PHÁT ĐI BÀ NÀ',
      );
      await tester.enterText(
        find.byKey(const Key('broadcast_content_input')),
        'Xe sẽ đón lúc 07:00 thay vì 07:30 để tránh kẹt cáp treo.',
      );
      await tester.tap(find.byKey(const Key('submit_broadcast_button')));
      await tester.pumpAndSettle();

      // Verify new broadcast card appears
      expect(find.text('ĐỔI GIỜ XUẤT PHÁT ĐI BÀ NÀ'), findsOneWidget);
      expect(
        find.text('Xe sẽ đón lúc 07:00 thay vì 07:30 để tránh kẹt cáp treo.'),
        findsOneWidget,
      );

      // Create a Roll Call via Action Drawer
      await tester.tap(find.byKey(const Key('open_action_drawer_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('action_create_roll_call')));
      await tester.pumpAndSettle();

      expect(find.text('Tạo điểm danh đoàn'), findsOneWidget);
      await tester.tap(find.text('Bắt đầu điểm danh'));
      await tester.pumpAndSettle();

      expect(find.text('Điểm danh xe di chuyển'), findsOneWidget);
      expect(find.text('Có mặt: 1/4 thành viên'), findsOneWidget);
    });

    testWidgets('Workflow 5: Search & Exception Boundary Testing', (
      tester,
    ) async {
      configureViewport(tester);
      await tester.pumpWidget(createChatWidget());
      await tester.pumpAndSettle();

      // 1. Toggle Search
      final toggleSearchBtn = find.byKey(const Key('toggle_search_button'));
      await tester.tap(toggleSearchBtn);
      await tester.pumpAndSettle();

      final searchInput = find.byKey(const Key('chat_search_input'));
      expect(searchInput, findsOneWidget);

      // Search matching keyword
      await tester.enterText(searchInput, 'Bánh tráng cuốn');
      await tester.pumpAndSettle();

      expect(
        find.text('Tiền ăn trưa Bánh tráng cuốn thịt heo Đại Lộc'),
        findsOneWidget,
      );
      expect(find.text('THÔNG BÁO TẬP TRUNG SÁNG MAI'), findsNothing);

      // Search non-existent keyword (Exception safety test)
      await tester.enterText(searchInput, 'tu_khoa_khong_ton_tai_999');
      await tester.pumpAndSettle();

      expect(find.text('Không tìm thấy tin nhắn nào'), findsOneWidget);

      // Clear search
      await tester.tap(toggleSearchBtn);
      await tester.pumpAndSettle();
      expect(find.text('THÔNG BÁO TẬP TRUNG SÁNG MAI'), findsOneWidget);

      // 2. Empty text input submission (Exception safety test)
      final textInput = find.byKey(const Key('chat_message_input'));
      final sendBtn = find.byKey(const Key('send_message_button'));

      await tester.enterText(textInput, '    ');
      await tester.tap(sendBtn);
      await tester.pumpAndSettle();

      // Verify no blank message was added to the chat bubbles
      expect(
        find.byWidgetPredicate((w) => w is Text && w.data == '    '),
        findsNothing,
      );
    });
  });
}
