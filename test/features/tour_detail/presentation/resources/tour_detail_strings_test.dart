import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/tour_detail/presentation/resources/tour_detail_strings.dart';

void main() {
  test('duration uses the singular for one day', () {
    expect(TourDetailStrings.durationDays(1), '1 day');
    expect(TourDetailStrings.durationDays(2), '2 days');
    expect(TourDetailStrings.durationDays(0), '0 days');
  });
}
