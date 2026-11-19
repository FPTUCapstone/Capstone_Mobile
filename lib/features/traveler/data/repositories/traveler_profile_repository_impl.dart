import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/traveler_profile_repository.dart';

class TravelerProfileRepositoryImpl implements TravelerProfileRepository {
  TravelerProfileRepositoryImpl(this.dio);
  final Dio dio;
  TravelerProfile _parse(dynamic value) {
    final data = Map<String, dynamic>.from(value as Map);
    return TravelerProfile(
      fullName: data['fullName'] as String,
      email: data['email'] as String,
      phoneNumber: (data['phoneNumber'] as String?)?.replaceAll(
        RegExp(r'\s+'),
        '',
      ),
      dateOfBirth: data['dateOfBirth'] as String?,
      avatarUrl: data['avatarUrl'] as String?,
    );
  }

  @override
  Future<TravelerProfile> load() async =>
      _parse((await dio.get<dynamic>('/api/v1/traveler/profile')).data);
  @override
  Future<TravelerProfile> save({
    required String fullName,
    required String phoneNumber,
    String? dateOfBirth,
    Uint8List? avatar,
    String? avatarName,
    String? avatarMime,
  }) async {
    final form = FormData.fromMap({
      'fullName': fullName.trim(),
      'phoneNumber': phoneNumber.replaceAll(RegExp(r'\s+'), ''),
      'dateOfBirth': ?dateOfBirth,
      if (avatar != null)
        'avatar': MultipartFile.fromBytes(
          avatar,
          filename: avatarName,
          contentType: DioMediaType.parse(avatarMime!),
        ),
    });
    final response = await dio.put<dynamic>(
      '/api/v1/traveler/profile',
      data: form,
    );
    return _parse((response.data as Map)['profile']);
  }
}
