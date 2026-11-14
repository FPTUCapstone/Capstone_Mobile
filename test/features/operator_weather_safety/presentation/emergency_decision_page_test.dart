import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/platform/device_window.dart';
import 'package:trip_mate_mobile/features/emergency_tour/domain/entities/emergency_action.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/domain/entities/emergency_decision.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/domain/usecases/operator_weather_safety_use_cases.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/presentation/cubit/emergency_decision_cubit.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/presentation/cubit/emergency_evidence_cubit.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/presentation/pages/emergency_decision_page.dart';

import '../support/emergency_fixtures.dart';
import '../support/fake_operator_weather_safety_repository.dart';

final class _FakeWindow implements DeviceWindow {
  @override
  Future<void> clearNotifications() async {}

  bool secure = false;

  @override
  Future<void> setSecure(bool value) async => secure = value;

  @override
  Future<bool> openNotificationSettings() async => true;
}

const cancelRefundCopy =
    'Mỗi booking đã thanh toán sẽ được hoàn 100% số tiền đã trả. '
    'Booking chưa thanh toán không phát sinh hoàn tiền.';
const stopRefundCopy =
    'Booking đã thanh toán sẽ được TripMate xem xét hoàn phần dịch vụ '
    'chưa thực hiện.';
const stopReviewResultCopy =
    'Các booking đã thanh toán đã được chuyển cho TripMate xem xét hoàn tiền.';

void main() {
  late FakeOperatorWeatherSafetyRepository repository;
  late FakeNetworkInfo network;
  var keys = 0;
  late _FakeWindow window;

  setUp(() {
    repository = FakeOperatorWeatherSafetyRepository();
    network = FakeNetworkInfo();
    keys = 0;
    window = _FakeWindow();
  });

  Future<EmergencyDecisionCubit> pump(
    WidgetTester tester, {
    double textScale = 1,
    Size size = const Size(400, 800),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final cubit = EmergencyDecisionCubit(
      tourId: 12,
      scheduleId: 31,
      getImpact: GetEmergencyImpactUseCase(repository),
      cancelBeforeDeparture: CancelBeforeDepartureUseCase(repository),
      emergencyStop: EmergencyStopTourUseCase(repository),
      networkInfo: network,
      newIdempotencyKey: () => 'key-${++keys}',
    );
    addTearDown(cubit.close);
    unawaited(cubit.load());
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: cubit),
            BlocProvider(
              create: (_) => EmergencyEvidenceCubit(
                tourId: 12,
                scheduleId: 31,
                save: SaveEmergencyEvidenceUseCase(repository),
                withdraw: WithdrawEmergencyEvidenceUseCase(repository),
                read: GetEmergencyEvidenceUseCase(repository),
                networkInfo: network,
              ),
            ),
          ],
          child: EmergencyDecisionPage(
            tourId: 12,
            scheduleId: 31,
            window: window,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return cubit;
  }

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String key, String text) async {
    final field = find.byKey(Key(key));
    await scrollTo(tester, field);
    await tester.enterText(field, text);
    await tester.pump();
  }

  Future<void> tapReview(WidgetTester tester) async {
    final button = find.byKey(const Key('emergency-review-decision'));
    await scrollTo(tester, button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Future<void> fillCancel(WidgetTester tester) =>
      enter(tester, 'emergency-reason-details', 'Storm warning');

  Future<void> fillStop(WidgetTester tester) async {
    await enter(tester, 'emergency-reason-details', 'Road closed');
    await enter(tester, 'emergency-instructions', 'Stay at the shelter.');
    await enter(tester, 'emergency-contact', '+84 900 000 000');
    await enter(tester, 'emergency-password', 'transient-value');
  }

  group('impact and fail-closed views', () {
    testWidgets('a cancellation explains the full refund before confirming', (
      tester,
    ) async {
      repository.impacts.add(impact());

      await pump(tester);

      expect(find.text('Hủy trước khởi hành'), findsWidgets);
      expect(find.textContaining('Hành khách bị ảnh hưởng'), findsOneWidget);
      expect(find.text(cancelRefundCopy), findsOneWidget);
      expect(find.text(stopRefundCopy), findsNothing);
      expect(find.textContaining('được xử lý riêng'), findsNothing);
      expect(find.textContaining('VND'), findsNothing);
    });

    testWidgets('a stop explains the refund review before confirming', (
      tester,
    ) async {
      repository.impacts.add(impact(action: EmergencyAction.emergencyStop));

      await pump(tester);

      expect(find.text(stopRefundCopy), findsOneWidget);
      expect(find.text(cancelRefundCopy), findsNothing);
      expect(find.textContaining('được xử lý riêng'), findsNothing);
    });

    testWidgets('an unknown action promises nothing about refunds', (
      tester,
    ) async {
      repository.impacts.add(impact(action: EmergencyAction.unknown));

      await pump(tester);

      expect(find.text(cancelRefundCopy), findsNothing);
      expect(find.text(stopRefundCopy), findsNothing);
    });

    testWidgets('unverified sessions hide the form and explain why', (
      tester,
    ) async {
      repository.impacts.add(impact(hasUnverifiedSessions: true));

      await pump(tester);

      expect(find.byKey(const Key('emergency-review-decision')), findsNothing);
      expect(find.textContaining('chưa được xác minh'), findsOneWidget);
    });

    testWidgets('offline hides the form and offers a re-check', (tester) async {
      network.connected = false;
      repository.impacts.add(impact());

      await pump(tester);

      expect(find.byKey(const Key('emergency-review-decision')), findsNothing);
      expect(find.textContaining('ngoại tuyến'), findsOneWidget);
      expect(find.text('Kiểm tra lại'), findsOneWidget);
    });

    testWidgets('a screen with no password stays capturable', (tester) async {
      repository.impacts.add(impact());

      await pump(tester);

      expect(window.secure, isFalse);
    });

    testWidgets('a foreign schedule is a Safe 404 that names nothing', (
      tester,
    ) async {
      repository.impacts.add(const NotFoundFailure());

      await pump(tester);

      expect(find.text('Không tìm thấy lịch khởi hành'), findsOneWidget);
      expect(find.byKey(const Key('emergency-impact-panel')), findsNothing);
    });

    testWidgets('a decided departure offers evidence and no decision', (
      tester,
    ) async {
      repository.impacts.add(
        const EmergencyTourFailure(
          'decided',
          reason: EmergencyTourFailureReason.terminal,
        ),
      );

      await pump(tester);

      expect(find.byKey(const Key('emergency-review-decision')), findsNothing);
      expect(find.byKey(const Key('evidence-editor')), findsOneWidget);
    });

    testWidgets('a decided departure past its end still offers evidence', (
      tester,
    ) async {
      repository.impacts.add(
        const EmergencyTourFailure(
          'ended',
          reason: EmergencyTourFailureReason.completed,
        ),
      );

      await pump(tester);

      expect(find.byKey(const Key('emergency-review-decision')), findsNothing);
      expect(find.byKey(const Key('evidence-editor')), findsOneWidget);
    });

    testWidgets('no Continue Tour command exists', (tester) async {
      repository.impacts.add(impact());

      await pump(tester);

      expect(find.textContaining('Continue'), findsNothing);
    });
  });

  group('Cancel Before Departure', () {
    testWidgets('requires reason details before checking the impact', (
      tester,
    ) async {
      repository.impacts.add(impact());
      await pump(tester);
      final before = repository.impactCalls;

      await tapReview(tester);

      expect(find.text('Vui lòng nhập lý do.'), findsOneWidget);
      expect(repository.impactCalls, before);
    });

    testWidgets('a missing field receives keyboard focus', (tester) async {
      repository.impacts.add(impact());
      await pump(tester);

      await tapReview(tester);

      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('emergency-reason-details')),
          matching: find.byType(TextField),
        ),
      );
      expect(field.focusNode!.hasFocus, isTrue);
    });

    testWidgets('confirmation summarises impact and sends only on consent', (
      tester,
    ) async {
      repository
        ..impacts.add(impact())
        ..commandOutcomes.add(operationResult);
      await pump(tester);
      await fillCancel(tester);

      await tapReview(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('5 hành khách'), findsOneWidget);
      expect(repository.commands, isEmpty);

      await tester.tap(find.byKey(const Key('emergency-confirm-cancel')));
      await tester.pumpAndSettle();
      expect(repository.commands, isEmpty);

      await tapReview(tester);
      await tester.tap(find.byKey(const Key('emergency-confirm-submit')));
      await tester.pumpAndSettle();

      expect(repository.commands, hasLength(1));
      expect(find.byKey(const Key('emergency-success')), findsOneWidget);
    });

    testWidgets('a cancellation reports how many refund requests it created', (
      tester,
    ) async {
      repository
        ..impacts.add(impact())
        ..commandOutcomes.add(decisionResult(refundsSubmitted: 2));
      await pump(tester);
      await fillCancel(tester);

      await tapReview(tester);
      await tester.tap(find.byKey(const Key('emergency-confirm-submit')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('emergency-success')), findsOneWidget);
      expect(
        find.textContaining('Đã tạo 2 yêu cầu hoàn tiền.'),
        findsOneWidget,
      );
      expect(find.textContaining(stopReviewResultCopy), findsNothing);
    });

    testWidgets('an older Backend without the refund count shows no count', (
      tester,
    ) async {
      repository
        ..impacts.add(impact())
        ..commandOutcomes.add(decisionResult());
      await pump(tester);
      await fillCancel(tester);

      await tapReview(tester);
      await tester.tap(find.byKey(const Key('emergency-confirm-submit')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('emergency-success')), findsOneWidget);
      expect(find.textContaining('yêu cầu hoàn tiền'), findsNothing);
      expect(find.textContaining(stopReviewResultCopy), findsNothing);
    });

    testWidgets('a stale impact keeps the form text and asks for review', (
      tester,
    ) async {
      repository.impacts.add(impact());
      await pump(tester);
      await fillCancel(tester);
      repository.impacts
        ..clear()
        ..add(impact(version: otherImpactVersion));

      await tapReview(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.textContaining('Tác động đã thay đổi'), findsOneWidget);
      expect(find.text('Storm warning'), findsOneWidget);
      expect(repository.commands, isEmpty);
    });

    testWidgets('an authority directive needs a reference or add-later', (
      tester,
    ) async {
      repository.impacts.add(impact());
      await pump(tester);
      await fillCancel(tester);
      final reason = find.byKey(const Key('emergency-reason'));
      await scrollTo(tester, reason);
      await tester.tap(reason);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chỉ thị của cơ quan chức năng').last);
      await tester.pumpAndSettle();

      await tapReview(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.textContaining('cơ quan ban hành'), findsOneWidget);
    });

    testWidgets('rejects a non-HTTPS evidence link', (tester) async {
      repository.impacts.add(impact());
      await pump(tester);
      await fillCancel(tester);
      await enter(tester, 'emergency-evidence-url', 'http://a.example/n');

      await tapReview(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.textContaining('HTTPS'), findsOneWidget);
    });
  });

  group('Emergency Stop', () {
    setUp(() {
      repository.impacts.add(impact(action: EmergencyAction.emergencyStop));
    });

    TextField passwordField(WidgetTester tester) => tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('emergency-password')),
        matching: find.byType(TextField),
      ),
    );

    testWidgets('the password screen is secure and restores on leaving', (
      tester,
    ) async {
      await pump(tester);

      expect(window.secure, isTrue);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();

      expect(window.secure, isFalse);
    });

    testWidgets('the password field cannot be autofilled or restored', (
      tester,
    ) async {
      await pump(tester);
      await scrollTo(tester, find.byKey(const Key('emergency-password')));

      final field = passwordField(tester);

      expect(field.obscureText, isTrue);
      expect(field.enableSuggestions, isFalse);
      expect(field.autocorrect, isFalse);
      expect(field.autofillHints, isNull);
      expect(field.restorationId, isNull);
      expect(field.enableIMEPersonalizedLearning, isFalse);
    });

    testWidgets('requires instructions, contact, due date and password', (
      tester,
    ) async {
      await pump(tester);
      await enter(tester, 'emergency-reason-details', 'Road closed');
      final before = repository.impactCalls;

      await tapReview(tester);

      expect(repository.impactCalls, before);
      expect(find.text('Vui lòng nhập chỉ dẫn khẩn cấp.'), findsOneWidget);
      expect(
        find.text('Vui lòng nhập đầu mối liên hệ khẩn cấp.'),
        findsOneWidget,
      );
      expect(find.text('Vui lòng nhập mật khẩu hiện tại.'), findsOneWidget);
      expect(find.byKey(const Key('emergency-refund-due')), findsNothing);
    });

    testWidgets('success clears the password', (tester) async {
      repository.commandOutcomes.add(operationResult);
      await pump(tester);
      await fillStop(tester);

      await tapReview(tester);
      await tester.tap(find.byKey(const Key('emergency-confirm-submit')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('emergency-success')), findsOneWidget);
      expect(find.text('transient-value'), findsNothing);
    });

    testWidgets('success says paid bookings went to TripMate review', (
      tester,
    ) async {
      repository.commandOutcomes.add(
        decisionResult(
          action: EmergencyAction.emergencyStop,
          refundsSubmitted: 0,
        ),
      );
      await pump(tester);
      await fillStop(tester);

      await tapReview(tester);
      await tester.tap(find.byKey(const Key('emergency-confirm-submit')));
      await tester.pumpAndSettle();

      expect(find.text('Đã dừng tour'), findsOneWidget);
      expect(find.textContaining(stopReviewResultCopy), findsOneWidget);
      expect(find.textContaining('Đã tạo'), findsNothing);
    });

    testWidgets('an impact change at review clears the password', (
      tester,
    ) async {
      repository.impacts.add(impact());
      await pump(tester);
      await fillStop(tester);
      final password = passwordField(tester).controller!;
      final instructions = tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const Key('emergency-instructions')),
              matching: find.byType(TextField),
            ),
          )
          .controller!;
      repository.impacts
        ..clear()
        ..add(impact(version: otherImpactVersion));

      await tapReview(tester);

      expect(find.textContaining('Tác động đã thay đổi'), findsOneWidget);
      expect(password.text, isEmpty);
      expect(instructions.text, 'Stay at the shelter.');
    });

    testWidgets('going offline clears the password', (tester) async {
      await pump(tester);
      await fillStop(tester);
      final controller = passwordField(tester).controller!;

      network.change(false);
      await tester.pumpAndSettle();

      expect(find.textContaining('ngoại tuyến'), findsOneWidget);
      expect(controller.text, isEmpty);
    });

    testWidgets('a wrong password is cleared, refocused and keeps the form', (
      tester,
    ) async {
      repository.commandOutcomes.add(
        const EmergencyTourFailure(
          'Không xác minh được mật khẩu. Vui lòng thử lại.',
          reason: EmergencyTourFailureReason.wrongPassword,
        ),
      );
      await pump(tester);
      await fillStop(tester);

      await tapReview(tester);
      await tester.tap(find.byKey(const Key('emergency-confirm-submit')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Không xác minh được mật khẩu'), findsWidgets);
      final field = passwordField(tester);
      expect(field.controller!.text, isEmpty);
      expect(field.focusNode!.hasFocus, isTrue);
      expect(find.text('Stay at the shelter.'), findsOneWidget);
    });

    testWidgets('cancelling the confirmation clears the password', (
      tester,
    ) async {
      await pump(tester);
      await fillStop(tester);

      await tapReview(tester);
      await tester.tap(find.byKey(const Key('emergency-confirm-cancel')));
      await tester.pumpAndSettle();

      expect(passwordField(tester).controller!.text, isEmpty);
      expect(find.text('Road closed'), findsOneWidget);
    });

    testWidgets('backgrounding the app clears the password', (tester) async {
      await pump(tester);
      await fillStop(tester);
      expect(passwordField(tester).controller!.text, 'transient-value');

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();

      expect(passwordField(tester).controller!.text, isEmpty);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });

    testWidgets('an ambiguous timeout offers only the identical retry', (
      tester,
    ) async {
      repository.commandOutcomes.addAll([
        const NetworkFailure(),
        operationResult,
      ]);
      await pump(tester);
      await fillStop(tester);
      await tapReview(tester);
      await tester.tap(find.byKey(const Key('emergency-confirm-submit')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Chưa xác nhận được'), findsOneWidget);
      expect(find.byKey(const Key('emergency-review-decision')), findsNothing);

      await enter(tester, 'emergency-password', 'transient-value');
      final retry = find.byKey(const Key('emergency-retry-submit'));
      await scrollTo(tester, retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();

      expect(repository.commands, hasLength(2));
      expect(repository.commands[0].key, repository.commands[1].key);
      expect(find.byKey(const Key('emergency-success')), findsOneWidget);
    });

    testWidgets('stays usable on a small screen with large text', (
      tester,
    ) async {
      await pump(tester, textScale: 2, size: const Size(320, 568));
      await fillStop(tester);

      await tapReview(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byKey(const Key('emergency-confirm-submit')), findsOneWidget);
    });
  });

  group('evidence editor', () {
    setUp(() {
      repository.impacts.add(
        const EmergencyTourFailure(
          'decided',
          reason: EmergencyTourFailureReason.terminal,
        ),
      );
    });

    testWidgets('opens with the saved evidence and keeps untouched fields', (
      tester,
    ) async {
      repository.currentEvidence = const EmergencyEvidenceSnapshot(
        evidence: EmergencyEvidence(reference: 'REF-1'),
        version: 'v1',
      );
      await pump(tester);
      expect(find.text('REF-1'), findsOneWidget);

      await enter(tester, 'evidence-url', 'https://authority.example/notice');
      final save = find.byKey(const Key('evidence-save'));
      await scrollTo(tester, save);
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(
        repository.evidenceCalls.single,
        const EmergencyEvidence(
          url: 'https://authority.example/notice',
          reference: 'REF-1',
        ),
      );
      expect(repository.lastExpectedVersion, 'v1');
    });

    testWidgets('saves a valid link and reference', (tester) async {
      await pump(tester);

      await enter(tester, 'evidence-url', 'https://authority.example/notice');
      await enter(tester, 'evidence-authority', 'NCHMF-1');
      final save = find.byKey(const Key('evidence-save'));
      await scrollTo(tester, save);
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(
        repository.evidenceCalls.single,
        const EmergencyEvidence(
          url: 'https://authority.example/notice',
          authorityReference: 'NCHMF-1',
        ),
      );
      expect(find.text('Đã lưu bằng chứng.'), findsOneWidget);
    });

    testWidgets('explains that emptying a field clears it', (tester) async {
      await pump(tester);

      expect(find.textContaining('ô bạn xóa trống'), findsOneWidget);
    });

    testWidgets('rejects a link with embedded credentials', (tester) async {
      await pump(tester);

      await enter(tester, 'evidence-url', 'https://user:pw@a.example/notice');
      final save = find.byKey(const Key('evidence-save'));
      await scrollTo(tester, save);
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(repository.evidenceCalls, isEmpty);
      expect(find.textContaining('HTTPS'), findsOneWidget);
    });

    testWidgets('an empty form saves nothing', (tester) async {
      await pump(tester);

      final save = find.byKey(const Key('evidence-save'));
      await scrollTo(tester, save);
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(repository.evidenceCalls, isEmpty);
      expect(
        find.textContaining('Vui lòng nhập liên kết hoặc'),
        findsOneWidget,
      );
    });

    testWidgets('withdraw asks first and sends no values', (tester) async {
      await pump(tester);

      final withdraw = find.byKey(const Key('evidence-withdraw'));
      await scrollTo(tester, withdraw);
      await tester.tap(withdraw);
      await tester.pumpAndSettle();
      expect(repository.evidenceCalls, isEmpty);

      await tester.tap(find.byKey(const Key('evidence-withdraw-confirm')));
      await tester.pumpAndSettle();

      expect(repository.evidenceCalls.single, isNull);
      expect(find.text('Đã rút lại bằng chứng.'), findsOneWidget);
    });
  });
}
