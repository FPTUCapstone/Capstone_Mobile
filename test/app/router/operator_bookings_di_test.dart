import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/features/operator_bookings/data/repositories/demo_operator_bookings_repository.dart';
import 'package:trip_mate_mobile/features/operator_bookings/data/repositories/operator_bookings_repository_impl.dart';
import 'package:trip_mate_mobile/features/operator_bookings/domain/repositories/operator_bookings_repository.dart';
import 'package:trip_mate_mobile/features/operator_bookings/presentation/cubit/operator_booking_detail_cubit.dart';
import 'package:trip_mate_mobile/features/operator_bookings/presentation/cubit/operator_bookings_cubit.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await serviceLocator.reset();
    await configureDependencies(
      config: AppConfig(
        environment: Environment.development,
        apiBaseUrl: Uri.parse('https://api.test.invalid'),
      ),
    );
  });

  tearDown(() => serviceLocator.reset());

  test('the demo repository is served only for an explicit demo flag', () {
    final demo = serviceLocator<OperatorBookingsRepository>(param1: true);
    final live = serviceLocator<OperatorBookingsRepository>(param1: false);

    expect(demo, isA<DemoOperatorBookingsRepository>());
    expect(live, isA<OperatorBookingsRepositoryImpl>());
    expect(live, isNot(isA<DemoOperatorBookingsRepository>()));
  });

  test('the Cubits are built for the live repository when demo is off', () async {
    final list = serviceLocator<OperatorBookingsCubit>(param1: false);
    final detail = serviceLocator<OperatorBookingDetailCubit>(
      param1: '1201',
      param2: false,
    );
    addTearDown(list.close);
    addTearDown(detail.close);

    expect(detail.bookingId, '1201');
    // Nothing is loaded by merely building them: the screen decides when to load.
    expect(list.state.items, isEmpty);
    expect(detail.state.detail, isNull);
  });

  test('a demo Cubit serves demo data and a live Cubit never does', () async {
    final demo = serviceLocator<OperatorBookingsCubit>(param1: true);
    final live = serviceLocator<OperatorBookingsCubit>(param1: false);
    addTearDown(demo.close);
    addTearDown(live.close);

    await demo.loadInitial();
    // The live repository points at an unreachable host: it fails, and a failure is never filled with fixtures.
    await live.loadInitial();

    expect(demo.state.items, isNotEmpty);
    expect(live.state.items, isEmpty);
    expect(live.state.isFailure, isTrue);
  });
}
