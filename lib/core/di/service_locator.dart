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
import 'package:trip_mate_mobile/features/poi/data/datasources/poi_remote_data_source.dart';
import 'package:trip_mate_mobile/features/poi/data/repositories/poi_repository_impl.dart';
import 'package:trip_mate_mobile/features/poi/data/services/geolocator_poi_location_service.dart';
import 'package:trip_mate_mobile/features/poi/domain/repositories/poi_location_service.dart';
import 'package:trip_mate_mobile/features/poi/domain/repositories/poi_repository.dart';
import 'package:trip_mate_mobile/features/poi/domain/usecases/get_poi_detail_use_case.dart';
import 'package:trip_mate_mobile/features/poi/domain/usecases/get_poi_location_use_case.dart';
import 'package:trip_mate_mobile/features/poi/domain/usecases/get_pois_use_case.dart';
import 'package:trip_mate_mobile/features/poi/presentation/cubit/poi_detail_cubit.dart';
import 'package:trip_mate_mobile/features/poi/presentation/cubit/poi_list_cubit.dart';

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
    ..registerLazySingleton<PoiRemoteDataSource>(
      () => DioPoiRemoteDataSource(serviceLocator()),
    )
    ..registerLazySingleton<PoiRepository>(
      () => PoiRepositoryImpl(serviceLocator()),
    )
    ..registerLazySingleton<PoiLocationService>(
      GeolocatorPoiLocationService.new,
    )
    ..registerFactory<GetPoisUseCase>(() => GetPoisUseCase(serviceLocator()))
    ..registerFactory<GetPoiDetailUseCase>(
      () => GetPoiDetailUseCase(serviceLocator()),
    )
    ..registerFactory<GetPoiLocationUseCase>(
      () => GetPoiLocationUseCase(serviceLocator()),
    )
    ..registerFactory<PoiListCubit>(
      () => PoiListCubit(
        getPois: serviceLocator(),
        getLocation: serviceLocator(),
      ),
    )
    ..registerFactory<PoiDetailCubit>(() => PoiDetailCubit(serviceLocator()))
    ..registerFactory<AuthSessionCubit>(AuthSessionCubit.new);
}
