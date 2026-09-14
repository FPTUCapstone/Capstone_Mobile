import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/auth/data/models/register_traveler_request.dart';

void main() {
  test('serializes only the backend register contract fields', () {
    const request = RegisterTravelerRequest(
      fullName: 'Nguyen Van A',
      email: 'traveler@example.com',
      password: 'Password123!',
      phoneNumber: '0912345678',
      acceptedTerms: true,
    );

    expect(request.toJson(), {
      'fullName': 'Nguyen Van A',
      'email': 'traveler@example.com',
      'password': 'Password123!',
      'phoneNumber': '0912345678',
      'acceptedTerms': true,
    });
    expect(request.toJson(), isNot(contains('confirmPassword')));
    expect(request.toJson(), isNot(contains('googleToken')));
    expect(request.toJson(), isNot(contains('phone')));
  });

  test('serializes an empty phone as null', () {
    const request = RegisterTravelerRequest(
      fullName: 'Nguyen Van A',
      email: 'traveler@example.com',
      password: 'Password123!',
      acceptedTerms: true,
    );

    expect(request.toJson()['phoneNumber'], isNull);
  });
}
