import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/tour_detail/data/datasources/demo_tour_detail_data_source.dart';
import 'package:trip_mate_mobile/features/tour_detail/data/datasources/pending_tour_detail_data_source.dart';
import 'package:trip_mate_mobile/features/tour_detail/data/repositories/tour_detail_repository_impl.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/repositories/tour_detail_repository.dart';

void main() {
  group('TourDetailRepository', () {
    test('demo source returns the requested known fixture', () async {
      const repository = TourDetailRepositoryImpl(DemoTourDetailDataSource());

      final detail = await repository.getTourDetail('demo-tour-1');

      expect(detail?.tourId, 'demo-tour-1');
    });

    test('demo source fails closed for unknown and malformed IDs', () async {
      const repository = TourDetailRepositoryImpl(DemoTourDetailDataSource());

      expect(await repository.getTourDetail('unknown'), isNull);
      expect(await repository.getTourDetail(''), isNull);
      expect(await repository.getTourDetail('../demo-tour-1'), isNull);
    });

    test('production source never synthesizes tour detail', () async {
      const repository = TourDetailRepositoryImpl(
        PendingTourDetailDataSource(),
      );

      await expectLater(
        repository.getTourDetail('123'),
        throwsA(isA<TourDetailIntegrationPendingException>()),
      );
    });
  });
}
