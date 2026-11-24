import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/tour_operator/data/repositories/operator_dashboard_repository_impl.dart';
import 'package:trip_mate_mobile/features/tour_operator/domain/entities/operator_dashboard_metrics.dart';
import 'package:trip_mate_mobile/features/tour_operator/domain/repositories/operator_dashboard_repository.dart';
import 'package:trip_mate_mobile/features/tour_operator/presentation/cubit/operator_dashboard_cubit.dart';
import 'package:trip_mate_mobile/features/tour_operator/presentation/widgets/operator_dashboard_metrics_panel.dart';

final sample = OperatorDashboardMetrics(
  activeTourCount: 4,
  monthlyBookingCount: 18,
  monthlyNetAmount: -12000,
  activeCouponCount: 3,
  asOfUtc: DateTime.utc(2026, 11, 19),
  monthStart: DateTime(2026, 11),
  monthEndExclusive: DateTime(2026, 12),
);

class FakeDashboardRepository implements OperatorDashboardRepository {
  int calls = 0;
  Future<OperatorDashboardMetrics> Function() response = () async => sample;

  @override
  Future<OperatorDashboardMetrics> load() {
    calls++;
    return response();
  }
}

void main() {
  test('maps the server month and signed net without recomputing it', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          expect(options.path, '/api/v1/operator/dashboard/metrics');
          expect(options.queryParameters, isEmpty);
          handler.resolve(
            Response(
              requestOptions: options,
              data: {
                'activeTourCount': 4,
                'monthlyBookingCount': 18,
                'monthlyNetAmount': -12000,
                'activeCouponCount': 3,
                'asOfUtc': '2026-11-19T00:00:00Z',
                'monthStart': '2026-11-01',
                'monthEndExclusive': '2026-12-01',
              },
            ),
          );
        },
      ),
    );
    final result = await OperatorDashboardRepositoryImpl(dio).load();
    expect(result.monthlyNetAmount, -12000);
    expect(result.activeTourCount, 4);
    expect(result.monthStart, DateTime(2026, 11));
  });

  test('malformed payload fails instead of inventing zero metrics', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response(requestOptions: options, data: {'activeTourCount': 0}),
          );
        },
      ),
    );
    await expectLater(
      OperatorDashboardRepositoryImpl(dio).load(),
      throwsA(isA<ServerFailure>()),
    );
  });

  test('guards concurrent requests and allows retry after failure', () async {
    final repo = FakeDashboardRepository();
    final pending = Completer<OperatorDashboardMetrics>();
    repo.response = () => pending.future;
    final cubit = OperatorDashboardCubit(repo);
    final first = cubit.load();
    await cubit.load();
    expect(repo.calls, 1);
    expect(cubit.state.loading, isTrue);
    pending.completeError(const ServerFailure('internal SQL error'));
    await first;
    expect(cubit.state.failed, isTrue);
    expect(cubit.state.metrics, isNull);
    repo.response = () async => sample;
    await cubit.load();
    expect(cubit.state.metrics, sample);
    expect(cubit.state.failed, isFalse);
    await cubit.close();
  });

  test(
    'a completed request cannot emit after the account shell closes',
    () async {
      final pending = Completer<OperatorDashboardMetrics>();
      final repo = FakeDashboardRepository()..response = () => pending.future;
      final cubit = OperatorDashboardCubit(repo);
      final request = cubit.load();
      await cubit.close();
      pending.complete(sample);
      await request;
      expect(cubit.isClosed, isTrue);
    },
  );

  testWidgets(
    'reloads on activation and foreground but demo never requests data',
    (tester) async {
      final repo = FakeDashboardRepository();
      final cubit = OperatorDashboardCubit(repo);
      addTearDown(cubit.close);
      Future<void> mount({required bool active, bool demo = false}) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: OperatorDashboardMetricsPanel(
                  cubit: cubit,
                  isActive: active,
                  isDemoMode: demo,
                  onNavigateToTab: (_) {},
                ),
              ),
            ),
          ),
        );
        if (active || demo) {
          await tester.pumpAndSettle();
        }
      }

      await mount(active: false);
      expect(repo.calls, 0);
      await mount(active: true);
      expect(repo.calls, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(repo.calls, 2);
      await mount(active: true, demo: true);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(repo.calls, 2);
      expect(find.text('38.500.000 VNĐ'), findsOneWidget);
    },
  );

  testWidgets('renders safe error, retries and keeps four navigation targets', (
    tester,
  ) async {
    final repo = FakeDashboardRepository()
      ..response = () async => throw const ServerFailure('internal SQL error');
    final cubit = OperatorDashboardCubit(repo);
    addTearDown(cubit.close);
    final tabs = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: OperatorDashboardMetricsPanel(
              cubit: cubit,
              onNavigateToTab: tabs.add,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('internal SQL'), findsNothing);
    expect(find.text('Thử lại'), findsOneWidget);
    repo.response = () async => sample;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('4 gói'), findsOneWidget);
    expect(find.text('-12.000 VNĐ'), findsOneWidget);
    for (final title in [
      'Tour đang hoạt động',
      'Đơn đặt tour trong tháng',
      'Thực nhận trong tháng',
      'Mã giảm giá đang hiệu lực',
    ]) {
      await tester.ensureVisible(find.text(title));
      await tester.tap(find.text(title));
    }
    expect(tabs, [1, 2, 3, 4]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading and zero data are distinct on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final pending = Completer<OperatorDashboardMetrics>();
    final repo = FakeDashboardRepository()..response = () => pending.future;
    final cubit = OperatorDashboardCubit(repo);
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: OperatorDashboardMetricsPanel(
              cubit: cubit,
              onNavigateToTab: (_) {},
            ),
          ),
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.complete(
      OperatorDashboardMetrics(
        activeTourCount: 0,
        monthlyBookingCount: 0,
        monthlyNetAmount: 0,
        activeCouponCount: 0,
        asOfUtc: sample.asOfUtc,
        monthStart: sample.monthStart,
        monthEndExclusive: sample.monthEndExclusive,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('0 gói'), findsOneWidget);
    expect(find.text('0 đơn'), findsOneWidget);
    expect(find.text('0 VNĐ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
