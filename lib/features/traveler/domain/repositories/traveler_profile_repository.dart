import 'dart:typed_data';

class TravelerProfile {
  const TravelerProfile({
    required this.fullName,
    required this.email,
    this.phoneNumber,
    this.dateOfBirth,
    this.avatarUrl,
  });
  final String fullName;
  final String email;
  final String? phoneNumber;
  final String? dateOfBirth;
  final String? avatarUrl;
}

abstract interface class TravelerProfileRepository {
  Future<TravelerProfile> load();
  Future<TravelerProfile> save({
    required String fullName,
    required String phoneNumber,
    String? dateOfBirth,
    Uint8List? avatar,
    String? avatarName,
    String? avatarMime,
  });
}
