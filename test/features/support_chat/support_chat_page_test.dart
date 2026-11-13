import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/support_chat/domain/entities/support_chat.dart';
import 'package:trip_mate_mobile/features/support_chat/domain/usecases/send_support_message.dart';
import 'package:trip_mate_mobile/features/support_chat/presentation/cubit/support_chat_cubit.dart';
import 'package:trip_mate_mobile/features/support_chat/presentation/pages/support_chat_page.dart';

import 'support_chat_test.dart' show FakeChatRepository;

void main() {
  late FakeChatRepository repository;
  late SupportChatCubit cubit;
  setUp(() {
    repository = FakeChatRepository();
    cubit = SupportChatCubit(SendSupportMessage(repository));
  });
  tearDown(() async {
    await cubit.close();
  });
  Future<void> mount(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: BlocProvider.value(value: cubit, child: const SupportChatPage()),
    ),
  );

  testWidgets(
    'result actions select a record in the same chat and Clear chat clears it',
    (tester) async {
      await mount(tester);
      await tester.enterText(find.bySemanticsLabel('Message'), 'Find tours');
      await tester.tap(find.byTooltip('Send message'));
      repository.pending.complete(
        const SupportChatReply(
          answer: 'Matching tour',
          sources: [],
          actions: [
            SupportChatAction(
              type: SupportChatActionType.selectContext,
              label: 'Choose beach tour',
              description: 'View available departures',
              context: SupportChatContext(kind: 'tour', id: '12'),
              prompt: 'Available departures',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Choose beach tour'), findsOneWidget);
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Choose beach tour'))
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );
      await tester.tap(find.text('Choose beach tour'));
      await tester.pump();
      expect(repository.requests.last.message, 'Available departures');
      expect(repository.requests.last.context?.id, '12');
      expect(repository.requests.last.history, hasLength(2));
      repository.complete();
      await tester.pumpAndSettle();
      expect(find.text('Find tours'), findsOneWidget);
      expect(find.text('Selected tour #12'), findsOneWidget);
      await tester.tap(find.byTooltip('Clear chat'));
      await tester.pumpAndSettle();
      expect(cubit.state.messages, isEmpty);
      expect(cubit.state.context, isNull);
    },
  );

  testWidgets('safe action navigates and back keeps route-scoped chat', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: AppRoutes.supportChat,
      routes: [
        GoRoute(
          path: AppRoutes.supportChat,
          builder: (_, _) =>
              BlocProvider.value(value: cubit, child: const SupportChatPage()),
        ),
        GoRoute(
          path: AppRoutes.bookTourPattern,
          builder: (_, state) => Scaffold(
            appBar: AppBar(title: const Text('Booking form')),
            body: Text(
              'Schedule ${state.uri.queryParameters['scheduleId']}, adults ${state.uri.queryParameters['adults']}',
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.enterText(find.bySemanticsLabel('Message'), 'Book tour');
    await tester.tap(find.byTooltip('Send message'));
    repository.pending.complete(
      const SupportChatReply(
        answer: 'Review your booking',
        sources: [],
        actions: [
          SupportChatAction(
            type: SupportChatActionType.navigate,
            label: 'Review booking',
            url: '/tours/12/book?scheduleId=34&adults=3',
          ),
          SupportChatAction(
            type: SupportChatActionType.navigate,
            label: 'Unsafe action',
            url: 'https://evil.test/tours/12',
          ),
          SupportChatAction(
            type: SupportChatActionType.navigate,
            label: 'Unsupported action',
            url: '/itineraries',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unsafe action'), findsNothing);
    expect(find.text('Unsupported action'), findsNothing);
    await tester.tap(find.bySemanticsLabel('Review booking'));
    await tester.pumpAndSettle();
    expect(find.text('Schedule 34, adults 3'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Review your booking'), findsOneWidget);
    expect(repository.requests, hasLength(1));
  });

  testWidgets('long action labels fit a narrow screen with keyboard and large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: BlocProvider.value(value: cubit, child: const SupportChatPage()),
      ),
    );
    await tester.enterText(find.bySemanticsLabel('Message'), 'Find a trip');
    await tester.tap(find.byTooltip('Send message'));
    repository.pending.complete(
      const SupportChatReply(
        answer: 'Your options',
        sources: [],
        actions: [
          SupportChatAction(
            type: SupportChatActionType.selectContext,
            label:
                'Choose this tour with a long accessible label that wraps across lines',
            description:
                'Review departure times and participant availability for this matching tour',
            context: SupportChatContext(kind: 'tour', id: '12'),
            prompt: 'Tour details',
          ),
          SupportChatAction(
            type: SupportChatActionType.navigate,
            label: 'View this tour',
            url: '/tours/12',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(find.byType(ListView), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(
      find.text(
        'Choose this tour with a long accessible label that wraps across lines',
      ),
      findsOneWidget,
    );
  });

  testWidgets('action replies preserve an unsent composer draft', (
    tester,
  ) async {
    await mount(tester);
    await tester.enterText(find.bySemanticsLabel('Message'), 'Find tours');
    await tester.tap(find.byTooltip('Send message'));
    repository.pending.complete(
      const SupportChatReply(
        answer: 'Matching tours',
        sources: [],
        actions: [
          SupportChatAction(
            type: SupportChatActionType.selectContext,
            label: 'Choose tour',
            context: SupportChatContext(kind: 'tour', id: '7'),
            prompt: 'Show this tour',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.bySemanticsLabel('Message'),
      'My unsent question',
    );
    await tester.tap(find.text('Choose tour'));
    await tester.pump();
    repository.complete();
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'My unsent question',
    );
  });

  testWidgets(
    'send, loading, plain text answer and keyboard-safe small screen',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await mount(tester);
      await tester.enterText(find.bySemanticsLabel('Message'), 'Help me');
      await tester.tap(find.byTooltip('Send message'));
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(repository.requests.single.message, 'Help me');
      repository.complete(answer: '<b>plain text</b>');
      await tester.pumpAndSettle();
      expect(find.text('<b>plain text</b>'), findsOneWidget);
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('error retry preserves question', (tester) async {
    await mount(tester);
    await tester.enterText(find.bySemanticsLabel('Message'), 'Help');
    await tester.tap(find.byTooltip('Send message'));
    repository.pending.completeError(const ServerFailure());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(repository.requests.last.message, 'Help');
    repository.complete();
    await tester.pumpAndSettle();
    expect(find.text('Helpful answer'), findsOneWidget);
  });

  testWidgets('sources render as plain text without a URL action', (
    tester,
  ) async {
    await mount(tester);
    await tester.enterText(find.bySemanticsLabel('Message'), 'Refund policy');
    await tester.tap(find.byTooltip('Send message'));
    repository.complete(
      sources: const [
        SupportChatSource(
          id: 'policy',
          title: '<b>Refund policy</b>',
          url: '/help/refunds',
        ),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.text('<b>Refund policy</b>'), findsNothing);
    await tester.tap(find.text('Sources (1)'));
    await tester.pumpAndSettle();
    expect(find.text('<b>Refund policy</b>'), findsOneWidget);
    expect(find.text('/help/refunds'), findsNothing);
  });

  testWidgets('explicit route context can be cleared without entering IDs', (
    tester,
  ) async {
    cubit.selectContext(const SupportChatContext(kind: 'refund', id: '12'));
    await mount(tester);
    expect(find.text('Selected refund #12'), findsOneWidget);
    await tester.tap(find.byTooltip('Clear context'));
    await tester.pumpAndSettle();
    expect(cubit.state.context, isNull);
    expect(
      find.text('Ask about tours, bookings, refunds or itineraries.'),
      findsOneWidget,
    );
    expect(repository.requests, isEmpty);
  });

  testWidgets(
    'tour choices group related actions in one padded full-width card',
    (tester) async {
      tester.view.physicalSize = const Size(360, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await mount(tester);
      await tester.enterText(find.bySemanticsLabel('Message'), 'Find a tour');
      await tester.tap(find.byTooltip('Send message'));
      repository.pending.complete(
        const SupportChatReply(
          answer: 'Choose a tour',
          sources: [],
          actions: [
            SupportChatAction(
              type: SupportChatActionType.selectContext,
              label: 'Tour Sơn Trà và Ngũ Hành Sơn',
              description: '650.000 VND/người lớn. Còn 20 chỗ.',
              context: SupportChatContext(kind: 'tour', id: '12'),
              prompt: 'Available departures',
            ),
            SupportChatAction(
              type: SupportChatActionType.navigate,
              label: 'Xem Tour Sơn Trà và Ngũ Hành Sơn',
              url: '/tours/12',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tour Sơn Trà và Ngũ Hành Sơn'), findsOneWidget);
      expect(find.text('Xem Tour Sơn Trà và Ngũ Hành Sơn'), findsNothing);
      expect(find.text('Ask about tour'), findsOneWidget);
      expect(find.text('View tour'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('support-tour-12'))).width,
        328,
      );
      await tester.ensureVisible(find.text('Ask about tour'));
      await tester.tap(find.text('Ask about tour'));
      await tester.pump();
      expect(repository.requests.last.context?.id, '12');
      repository.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('leaving page during response does not update disposed scroll', (
    tester,
  ) async {
    await mount(tester);
    await tester.enterText(find.bySemanticsLabel('Message'), 'Help');
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    repository.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
