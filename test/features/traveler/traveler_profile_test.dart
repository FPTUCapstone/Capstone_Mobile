import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/data/repositories/traveler_profile_repository_impl.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/traveler_profile_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/traveler_profile_cubit.dart';

class _ControlledProfileRepository implements TravelerProfileRepository {
  final requests = <Completer<TravelerProfile>>[];
  @override
  Future<TravelerProfile> load() {
    final request = Completer<TravelerProfile>();
    requests.add(request);
    return request.future;
  }

  @override
  Future<TravelerProfile> save({
    required String fullName,
    required String phoneNumber,
    String? dateOfBirth,
    Uint8List? avatar,
    String? avatarName,
    String? avatarMime,
  }) => throw UnimplementedError();
}

void main() {
  test('an older profile request cannot restore the previous avatar', () async {
    final repository = _ControlledProfileRepository();
    final cubit = TravelerProfileCubit(repository);
    final older = cubit.load();
    final newer = cubit.load();
    repository.requests[1].complete(
      const TravelerProfile(
        fullName: 'Updated',
        email: 'test@example.com',
        avatarUrl: 'https://example.com/new.png',
      ),
    );
    await newer;
    repository.requests[0].complete(
      const TravelerProfile(
        fullName: 'Old',
        email: 'test@example.com',
        avatarUrl: 'https://example.com/old.png',
      ),
    );
    await older;
    expect(cubit.state.profile?.fullName, 'Updated');
    expect(cubit.state.profile?.avatarUrl, 'https://example.com/new.png');
    await cubit.close();
  });
  const profile = {
    'fullName': 'Updated name',
    'email': 'test@example.com',
    'phoneNumber': '0901234567',
    'dateOfBirth': null,
    'avatarUrl': 'https://example.com/avatar.png',
  };
  test(
    'sends normalized phone and multipart avatar, accepts persisted server profile',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.method, 'PUT');
            final data = options.data as FormData;
            expect(Map.fromEntries(data.fields)['phoneNumber'], '0901234567');
            expect(data.files.single.key, 'avatar');
            expect(data.files.single.value.contentType.toString(), 'image/png');
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {'profile': profile},
              ),
            );
          },
        ),
      );
      final cubit = TravelerProfileCubit(TravelerProfileRepositoryImpl(dio));
      await cubit.save(
        fullName: 'Updated name',
        phoneNumber: '090 123 4567',
        avatar: Uint8List.fromList([1, 2]),
        avatarName: 'avatar.png',
        avatarMime: 'image/png',
      );
      expect(cubit.state.saved, isTrue);
      expect(cubit.state.profile?.fullName, 'Updated name');
      await cubit.close();
    },
  );
  test('does not report success when backend rejects update', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(DioException(requestOptions: options));
        },
      ),
    );
    final cubit = TravelerProfileCubit(TravelerProfileRepositoryImpl(dio));
    await cubit.save(fullName: 'Updated name', phoneNumber: '0901234567');
    expect(cubit.state.saved, isFalse);
    expect(cubit.state.error, isNotNull);
    await cubit.close();
  });
}
