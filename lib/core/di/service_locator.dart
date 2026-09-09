import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/core/network/network_info.dart';
import 'package:trip_mate_mobile/core/storage/preferences_service.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/data/repositories/travel_group_repository_impl.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/travel_group_repository.dart';

final GetIt serviceLocator = GetIt.instance;

Future<void> configureDependencies({AppConfig? config}) async {
  if (serviceLocator.isRegistered<AppConfig>()) {
    return;
  }

  final preferences = await SharedPreferences.getInstance();
  serviceLocator
    ..registerSingleton<AppConfig>(config ?? AppConfig.fromEnvironment())
    ..registerSingleton<PreferencesService>(
      SharedPreferencesService(preferences),
    )
    ..registerLazySingleton<SecureStorageService>(
      () => const FlutterSecureStorageService(FlutterSecureStorage()),
    )
    ..registerLazySingleton<Connectivity>(Connectivity.new)
    ..registerLazySingleton<NetworkInfo>(
      () => ConnectivityNetworkInfo(serviceLocator()),
    )
    ..registerLazySingleton<DioClient>(
      () =>
          DioClient(config: serviceLocator(), secureStorage: serviceLocator()),
    )
    ..registerLazySingleton<TravelGroupRepository>(
      () => TravelGroupRepositoryImpl(dioClient: serviceLocator()),
    )
    ..registerFactory<AuthSessionCubit>(AuthSessionCubit.new);
}
