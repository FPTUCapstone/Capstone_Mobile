import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/tour_detail/presentation/resources/tour_detail_strings.dart';

void main() {
  test('duration formats day counts in Vietnamese', () {
    expect(TourDetailStrings.durationDays(1), '1 ngày');
    expect(TourDetailStrings.durationDays(2), '2 ngày');
    expect(TourDetailStrings.durationDays(0), '0 ngày');
  });
}
