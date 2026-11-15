import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/support_chat/presentation/support_chat_navigation.dart';

void main() {
  test('maps feature navigation to the corresponding mobile screens', () {
    expect(
      SupportChatNavigation.locationFor('/plan'),
      '/traveler/itineraries/create',
    );
    expect(SupportChatNavigation.locationFor('/pois'), '/explore');
    expect(
      SupportChatNavigation.locationFor('/account/profile'),
      '/traveler/profile',
    );
    expect(
      SupportChatNavigation.locationFor('/account/preferences'),
      '/traveler/preferences',
    );
    expect(
      SupportChatNavigation.locationFor('/account/security'),
      '/traveler/change-password',
    );
    expect(SupportChatNavigation.locationFor('/plan?next=//evil.test'), isNull);
  });

  test('preserves every participant category in a booking handoff', () {
    expect(
      SupportChatNavigation.locationFor(
        '/tours/101/book?scheduleId=11004&adults=2&children=1&infants=0',
      ),
      '/explore/tours/101/book?scheduleId=11004&adults=2&children=1&infants=0',
    );
    expect(
      SupportChatNavigation.locationFor(
        '/tours/101/book?scheduleId=11004&adults=50&children=1',
      ),
      isNull,
    );
  });
  test('maps supported canonical destinations to actual mobile routes', () {
    expect(SupportChatNavigation.locationFor('/tours'), '/explore/tours');
    expect(SupportChatNavigation.locationFor('/tours/12'), '/explore/tours/12');
    expect(
      SupportChatNavigation.locationFor('/account/trips'),
      '/traveler/trips',
    );
    expect(
      SupportChatNavigation.locationFor('/itinerary/5'),
      '/traveler/itineraries/5',
    );
    expect(
      SupportChatNavigation.locationFor('/bookings/7/refund'),
      '/bookings/7/refund',
    );
    expect(SupportChatNavigation.locationFor('/itineraries'), isNull);
    expect(SupportChatNavigation.locationFor('/partner/bookings'), isNull);
  });

  test('preserves selected schedule and bounded adult count for booking', () {
    expect(
      SupportChatNavigation.locationFor(
        '/tours/12/book?scheduleId=34&adults=3',
      ),
      '/explore/tours/12/book?scheduleId=34&adults=3',
    );
    expect(
      SupportChatNavigation.locationFor(
        '/tours/12/book?adults=50&scheduleId=34',
      ),
      '/explore/tours/12/book?scheduleId=34&adults=50',
    );
    expect(
      SupportChatNavigation.locationFor('/tours/12/book?scheduleId=34'),
      '/explore/tours/12/book?scheduleId=34',
    );
  });

  test('omits unsafe URLs, unsupported paths, and invalid resource IDs', () {
    for (final url in [
      'https://evil.test/tours/12',
      '//evil.test/tours/12',
      'javascript:alert(1)',
      r'\tours\12',
      '/tours/%31',
      '/tours/../12',
      '/tours/12#fragment',
      '/tours/12?demo=true',
      '/tours/12/',
      '/explore/tours/12',
      '/tours/0',
      '/tours/9223372036854775808',
      '/itinerary/-1',
      '/bookings/abc/refund',
      '/account/trips?tab=1',
      '/tours/12\n',
    ]) {
      expect(SupportChatNavigation.locationFor(url), isNull, reason: url);
    }
    expect(
      SupportChatNavigation.locationFor('/tours/00012'),
      '/explore/tours/12',
    );
  });

  test('rejects ambiguous or invalid booking query parameters', () {
    for (final query in [
      '',
      'adults=2',
      'scheduleId=0',
      'scheduleId=34&adults=0',
      'scheduleId=34&adults=51',
      'scheduleId=34&adults=-1',
      'scheduleId=34&adults=1.0',
      'scheduleId=34&adults=abc',
      'scheduleId=34&adults=',
      'scheduleId=34&adults=+2',
      'scheduleId=34&scheduleId=35',
      'scheduleId=34&adults=2&adults=3',
      'scheduleId=34&demo=true',
      'scheduleId=%33%34',
      'scheduleId=9223372036854775808',
      'scheduleId=34#fragment',
      'scheduleId=34&',
    ]) {
      final url = '/tours/12/book?$query';
      expect(SupportChatNavigation.locationFor(url), isNull, reason: url);
    }
  });
}
