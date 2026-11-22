import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/travel_group_chat_page.dart';

void main() {
  const testGroup = TravelGroup(
    id: 10,
    name: 'Đoàn Khám Phá Đà Nẵng - Hội An',
    inviteCode: 'DNHA2026',
    itineraryId: 5,
  );

  Widget createChatWidget({TravelGroup? group}) {
    return MaterialApp(
      home: TravelGroupChatPage(
        groupId: 10,
        group: group ?? testGroup,
        currentUserId: 1,
        currentUserName: 'Bạn',
      ),
    );
  }

  void configureViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
  }

  group('TravelGroupChatPage Widget Tests', () {
    testWidgets('renders group name, active members count, and pinned announcement', (
      tester,
    ) async {
      configureViewport(tester);
      await tester.pumpWidget(createChatWidget());
      await tester.pumpAndSettle();

      expect(find.text('Đoàn Khám Phá Đà Nẵng - Hội An'), findsOneWidget);
      expect(find.text('4 thành viên • Đang hoạt động'), findsOneWidget);
      expect(find.textContaining('Ghim: Tập trung lúc 07:30'), findsOneWidget);
    });

    testWidgets('user can dismiss pinned announcement', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(createChatWidget());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('dismiss_pinned_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('dismiss_pinned_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('dismiss_pinned_button')), findsNothing);
    });

    testWidgets('displays Tour Guide broadcast card and allows acknowledgment', (
      tester,
    ) async {
      configureViewport(tester);
      await tester.pumpWidget(createChatWidget());
      await tester.pumpAndSettle();

      expect(find.text('THÔNG BÁO TẬP TRUNG SÁNG MAI'), findsOneWidget);
      expect(find.text('QUAN TRỌNG'), findsOneWidget);
      expect(find.text('3/4 đã đọc'), findsOneWidget);

      final ackBtn = find.byKey(const Key('broadcast_ack_msg-2'));
      expect(ackBtn, findsOneWidget);
      await tester.tap(ackBtn);
      await tester.pumpAndSettle();

      expect(find.text('4/4 đã đọc'), findsOneWidget);
      expect(find.text('Đã đọc'), findsOneWidget);
    });

    testWidgets('displays Roll Call card and allows check-in', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(createChatWidget());
      await tester.pumpAndSettle();

      expect(find.text('Điểm danh: Tập trung xe buýt số 1'), findsOneWidget);
      expect(find.text('Có mặt: 3/4 thành viên'), findsOneWidget);

      final rollCallBtn = find.byKey(const Key('roll_call_button_msg-3'));
      expect(rollCallBtn, findsOneWidget);
      await tester.tap(rollCallBtn);
      await tester.pumpAndSettle();

      expect(find.text('Có mặt: 4/4 thành viên'), findsOneWidget);
      expect(find.text('Đã có mặt'), findsOneWidget);
    });

    testWidgets('displays Poll card and allows voting', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(createChatWidget());
      await tester.pumpAndSettle();

      expect(
        find.text('Tối nay cả nhóm mình đi ăn gì ở Phố cổ Hội An?'),
        findsOneWidget,
      );

      final option0 = find.byKey(const Key('poll_option_msg-7_0'));
      expect(option0, findsOneWidget);
      expect(find.text('2 phiếu'), findsOneWidget);

      // Tap to vote for option 0
      await tester.tap(option0);
      await tester.pumpAndSettle();

      expect(find.text('3 phiếu'), findsOneWidget);
    });

    testWidgets('user can send a new text message', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(createChatWidget());
      await tester.pumpAndSettle();

      final input = find.byKey(const Key('chat_message_input'));
      final sendBtn = find.byKey(const Key('send_message_button'));

      await tester.enterText(input, 'Xin chào mọi người!');
      await tester.tap(sendBtn);
      await tester.pumpAndSettle();

      expect(find.text('Xin chào mọi người!'), findsOneWidget);
      expect(find.text('Nhập tin nhắn...'), findsOneWidget);
    });

    testWidgets('search feature filters messages in real time', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(createChatWidget());
      await tester.pumpAndSettle();

      final toggleSearchBtn = find.byKey(const Key('toggle_search_button'));
      await tester.tap(toggleSearchBtn);
      await tester.pumpAndSettle();

      final searchInput = find.byKey(const Key('chat_search_input'));
      expect(searchInput, findsOneWidget);

      await tester.enterText(searchInput, 'Bánh mì Phượng');
      await tester.pumpAndSettle();

      expect(find.textContaining('Bánh mì Phượng'), findsOneWidget);
      expect(find.text('THÔNG BÁO TẬP TRUNG SÁNG MAI'), findsNothing);
    });

    testWidgets('opens VietQR modal from Split Bill card and toggles paid status', (
      tester,
    ) async {
      configureViewport(tester);
      await tester.pumpWidget(createChatWidget());
      await tester.pumpAndSettle();

      final openQrBtn = find.byKey(const Key('open_vietqr_button_msg-6'));
      expect(openQrBtn, findsOneWidget);

      await tester.tap(openQrBtn);
      await tester.pumpAndSettle();

      expect(find.text('Thanh toán qua VietQR'), findsOneWidget);
      expect(find.text('MB Bank'), findsOneWidget);
      expect(find.text('0987654321'), findsOneWidget);
      expect(find.text('LE THI HUONG'), findsOneWidget);
      expect(find.text('150.000 đ'), findsNWidgets(2));

      // Toggle paid status
      final togglePaidBtn = find.byKey(const Key('toggle_paid_button'));
      expect(togglePaidBtn, findsOneWidget);
      await tester.tap(togglePaidBtn);
      await tester.pumpAndSettle();

      // Modal closed and status updated
      expect(find.text('Đã trả • VietQR'), findsOneWidget);
      expect(find.text('Đã thanh toán: 3/4'), findsOneWidget);
    });

    testWidgets('opens action drawer and creates a new poll with validation', (
      tester,
    ) async {
      configureViewport(tester);
      await tester.pumpWidget(createChatWidget());
      await tester.pumpAndSettle();

      final drawerBtn = find.byKey(const Key('open_action_drawer_button'));
      await tester.tap(drawerBtn);
      await tester.pumpAndSettle();

      expect(find.text('Tiện ích nhóm du lịch'), findsOneWidget);
      expect(find.text('Tạo bình chọn (Voting)'), findsOneWidget);
      expect(find.text('Chia tiền hóa đơn (VietQR)'), findsOneWidget);
      expect(find.text('Thông báo khẩn (Dành cho HDV)'), findsOneWidget);
      expect(find.text('Điểm danh đoàn (Dành cho HDV)'), findsOneWidget);

      // Tap create poll
      await tester.tap(find.byKey(const Key('action_create_poll')));
      await tester.pumpAndSettle();

      expect(find.text('Tạo bình chọn mới'), findsOneWidget);

      // Submit empty should show validation error
      await tester.tap(find.byKey(const Key('submit_poll_button')));
      await tester.pumpAndSettle();
      expect(
        find.text('Vui lòng nhập câu hỏi và ít nhất 2 lựa chọn.'),
        findsOneWidget,
      );

      // Fill in valid poll data
      await tester.enterText(
        find.byKey(const Key('poll_question_input')),
        'Chọn phương tiện đi Bà Nà Hills?',
      );
      await tester.enterText(
        find.byKey(const Key('poll_option_1_input')),
        'Thuê xe du lịch 7 chỗ',
      );
      await tester.enterText(
        find.byKey(const Key('poll_option_2_input')),
        'Đi xe buýt đưa đón',
      );

      await tester.tap(find.byKey(const Key('submit_poll_button')));
      await tester.pumpAndSettle();

      expect(
        find.text('Chọn phương tiện đi Bà Nà Hills?'),
        findsOneWidget,
      );
      expect(find.text('Thuê xe du lịch 7 chỗ'), findsOneWidget);
    });
  });
}
