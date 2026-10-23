import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/trip_history/data/repositories/demo_trip_records_repository.dart';
import 'package:trip_mate_mobile/features/trip_history/data/repositories/trip_records_repository_impl.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_enums.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_record.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_record_detail.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/repositories/trip_records_repository.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/usecases/trip_records_use_case.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/cubit/trip_record_detail_cubit.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/cubit/trip_records_cubit.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/cubit/trip_records_state.dart';

final class _RecordingRepository implements TripRecordsRepository {
  _RecordingRepository({this.failure});

  final Failure? failure;
  TripRecordsQuery? lastQuery;
  (TripRecordKind, int)? lastDetail;

  @override
  Future<TripRecordPage> getPage(TripRecordsQuery query) async {
    lastQuery = query;
    if (failure != null) throw failure!;
    return const TripRecordPage(
      items: [],
      page: 1,
      pageSize: 20,
      totalCount: 0,
    );
  }

  @override
  Future<TripRecordDetail> getDetail(TripRecordKind kind, int id) async {
    lastDetail = (kind, id);
    throw failure ?? const NotFoundFailure();
  }
}

void main() {
  group('TripRecordsUseCase', () {
    test('hands the query to the repository and returns its page', () async {
      final repository = _RecordingRepository();
      final useCase = TripRecordsUseCase(repository);
      const query = TripRecordsQuery(
        tab: TripStatus.cancelled,
        tripType: TripRecordTypeFilter.tourBooking,
        page: 2,
      );

      final page = await useCase.page(query);

      expect(repository.lastQuery, query);
      expect(page.totalCount, 0);
    });

    test('hands the (kind, id) pair to the repository', () async {
      final repository = _RecordingRepository();

      await expectLater(
        TripRecordsUseCase(repository).detail(TripRecordKind.itinerary, 45),
        throwsA(isA<NotFoundFailure>()),
      );

      expect(repository.lastDetail, (TripRecordKind.itinerary, 45));
    });

    test('lets a failure through unchanged', () async {
      final useCase = TripRecordsUseCase(
        _RecordingRepository(failure: const PermissionFailure()),
      );

      await expectLater(
        useCase.page(const TripRecordsQuery(tab: TripStatus.upcoming)),
        throwsA(isA<PermissionFailure>()),
      );
    });
  });

  group('container', () {
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

    test('production uses the Dio repository and demo uses the demo one', () {
      expect(
        serviceLocator<TripRecordsRepository>(param1: false),
        isA<TripRecordsRepositoryImpl>(),
      );
      expect(
        serviceLocator<TripRecordsRepository>(param1: true),
        isA<DemoTripRecordsRepository>(),
      );
    });

    test(
      'the use case is built over the repository chosen by the flag',
      () async {
        final demo = serviceLocator<TripRecordsUseCase>(param1: true);
        final page = await demo.page(
          const TripRecordsQuery(tab: TripStatus.completed),
        );

        expect(page.items, isNotEmpty);
        expect(serviceLocator<TripRecordsUseCase>(param1: false), isNotNull);
      },
    );

    test(
      'composes the list cubit over the repository chosen by the flag',
      () async {
        final demo = serviceLocator<TripRecordsCubit>(param1: true);
        addTearDown(demo.close);

        await demo.switchTab(TripStatus.completed);

        expect(demo.state.status, TripRecordsStatus.success);
        expect(demo.state.items, isNotEmpty);
        final production = serviceLocator<TripRecordsCubit>(param1: false);
        addTearDown(production.close);
        expect(production.state.status, TripRecordsStatus.initial);
      },
    );

    test('composes the detail cubit for one record', () async {
      final demo = serviceLocator<TripRecordDetailCubit>(
        param1: const TripRecordRef(kind: TripRecordKind.itinerary, id: 5001),
        param2: true,
      );
      addTearDown(demo.close);

      await demo.load();

      expect(demo.state.detail?.record.id, 5001);
    });
  });
}
