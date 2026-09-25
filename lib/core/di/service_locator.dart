import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/core/location/device_location_service.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/core/network/network_info.dart';
import 'package:trip_mate_mobile/core/network/session_coordinator.dart';
import 'package:trip_mate_mobile/core/storage/preferences_service.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:trip_mate_mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:trip_mate_mobile/features/auth/data/services/firebase_auth_service.dart';
import 'package:trip_mate_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:trip_mate_mobile/features/auth/domain/services/auth_identity_service.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/register_cubit.dart';
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
import 'package:trip_mate_mobile/features/tour_search/data/datasources/tour_search_remote_data_source.dart';
import 'package:trip_mate_mobile/features/tour_search/data/repositories/tour_search_repository_impl.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/repositories/tour_search_repository.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/usecases/search_tours_use_case.dart';
import 'package:trip_mate_mobile/features/tour_search/presentation/cubit/tour_search_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/data/repositories/itinerary_repository_impl.dart';
import 'package:trip_mate_mobile/features/traveler/data/repositories/point_of_interest_repository_impl.dart';
import 'package:trip_mate_mobile/features/traveler/data/repositories/travel_group_repository_impl.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/itinerary_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/point_of_interest_repository.dart';
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
    ..registerLazySingleton<GoogleSignIn>(() => GoogleSignIn.instance)
    ..registerLazySingleton<AuthIdentityService>(
      () => Firebase.apps.isEmpty
          ? const UnavailableFirebaseAuthService()
          : FirebaseAuthServiceImpl(FirebaseAuth.instance, serviceLocator()),
    )
    ..registerLazySingleton<NetworkInfo>(
      () => ConnectivityNetworkInfo(serviceLocator()),
    )
    ..registerLazySingleton<SessionCoordinator>(SessionCoordinator.new)
    ..registerLazySingleton<DeviceLocationService>(
      GeolocatorDeviceLocationService.new,
    )
    ..registerLazySingleton<DioClient>(
      () => DioClient(
        config: serviceLocator(),
        secureStorage: serviceLocator(),
        coordinator: serviceLocator(),
      ),
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
    // ── Tour Search ────────────────────────────────────────────────────
    ..registerLazySingleton<TourSearchRemoteDataSource>(
      () => DioTourSearchRemoteDataSource(serviceLocator()),
    )
    ..registerLazySingleton<TourSearchRepository>(
      () => TourSearchRepositoryImpl(serviceLocator()),
    )
    ..registerFactory<SearchToursUseCase>(
      () => SearchToursUseCase(serviceLocator()),
    )
    ..registerFactory<TourSearchCubit>(
      () => TourSearchCubit(searchTours: serviceLocator()),
    )
    ..registerLazySingleton<AuthRemoteDataSource>(
      () => AuthRemoteDataSourceImpl(serviceLocator()),
    )
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(serviceLocator()),
    )
    ..registerLazySingleton<TravelGroupRepository>(
      () => TravelGroupRepositoryImpl(dioClient: serviceLocator()),
    )
    ..registerLazySingleton<ItineraryRepository>(
      () => ItineraryRepositoryImpl(dioClient: serviceLocator()),
    )
    ..registerLazySingleton<PointOfInterestRepository>(
      () => PointOfInterestRepositoryImpl(dioClient: serviceLocator()),
    )
    ..registerFactory<AuthSessionCubit>(
      () => AuthSessionCubit(
        serviceLocator(),
        serviceLocator(),
        serviceLocator(),
      ),
    )
    ..registerFactory<RegisterCubit>(
      () => RegisterCubit(serviceLocator(), serviceLocator()),
    );
}
