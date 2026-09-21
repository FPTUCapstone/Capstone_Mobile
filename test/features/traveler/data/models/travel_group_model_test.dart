import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/data/models/travel_group_model.dart';

void main() {
  test('parses the create travel group response contract', () {
    final model = TravelGroupModel.fromJson({
      'groupId': 42,
      'groupName': 'Summer Trip',
      'itineraryId': 1001,
      'hostUserId': 5,
      'createdAt': '2026-09-08T10:30:00Z',
    });

    expect(model.id, 42);
    expect(model.name, 'Summer Trip');
  });

  test('rejects a malformed response instead of fabricating success data', () {
    expect(
      () => TravelGroupModel.fromJson({'groupId': 42}),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects a response with a missing itineraryId', () {
    expect(
      () => TravelGroupModel.fromJson({
        'groupId': 42,
        'groupName': 'Summer Trip',
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects a response with a non-positive or non-integer itineraryId', () {
    expect(
      () => TravelGroupModel.fromJson({
        'groupId': 42,
        'groupName': 'Summer Trip',
        'itineraryId': 0,
      }),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => TravelGroupModel.fromJson({
        'groupId': 42,
        'groupName': 'Summer Trip',
        'itineraryId': '1001',
      }),
      throwsA(isA<FormatException>()),
    );
  });
}
