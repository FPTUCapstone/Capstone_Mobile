import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';

void main() {
  group('AppRoutes.bookTour', () {
    test('includes an optional adult prefill count', () {
      expect(
        AppRoutes.bookTour('tour-1', 'schedule-2', adults: 4),
        '/explore/tours/tour-1/book?scheduleId=schedule-2&adults=4',
      );
    });

    test('preserves the existing route when an adult prefill is absent', () {
      expect(
        AppRoutes.bookTour('tour-1', 'schedule-2'),
        '/explore/tours/tour-1/book?scheduleId=schedule-2',
      );
    });
  });
}
