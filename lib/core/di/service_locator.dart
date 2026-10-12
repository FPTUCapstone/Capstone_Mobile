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
import 'package:trip_mate_mobile/features/auth/data/repositories/operator_application_repository_impl.dart';
import 'package:trip_mate_mobile/features/auth/data/repositories/tour_operator_registration_repository_impl.dart';
import 'package:trip_mate_mobile/features/auth/data/services/firebase_auth_service.dart';
import 'package:trip_mate_mobile/features/auth/data/services/firebase_operator_registration_identity_service.dart';
import 'package:trip_mate_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:trip_mate_mobile/features/auth/domain/repositories/operator_application_repository.dart';
import 'package:trip_mate_mobile/features/auth/domain/repositories/tour_operator_registration_repository.dart';
import 'package:trip_mate_mobile/features/auth/domain/services/auth_identity_service.dart';
import 'package:trip_mate_mobile/features/auth/domain/services/operator_registration_identity_service.dart';
import 'package:trip_mate_mobile/features/auth/domain/usecases/fetch_operator_application.dart';
import 'package:trip_mate_mobile/features/auth/domain/usecases/register_tour_operator.dart';
import 'package:trip_mate_mobile/features/auth/domain/usecases/resubmit_operator_application.dart';
import 'package:trip_mate_mobile/features/auth/password_recovery/data/datasources/password_recovery_remote_data_source.dart';
import 'package:trip_mate_mobile/features/auth/password_recovery/data/repositories/password_recovery_repository_impl.dart';
import 'package:trip_mate_mobile/features/auth/password_recovery/domain/repositories/password_recovery_repository.dart';
import 'package:trip_mate_mobile/features/auth/password_recovery/presentation/cubit/password_recovery_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/operator_application_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/operator_email_recovery_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/register_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/register_operator_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/services/operator_document_picker.dart';
import 'package:trip_mate_mobile/features/coupon/data/datasources/coupon_remote_data_source.dart';
import 'package:trip_mate_mobile/features/coupon/data/repositories/coupon_repository_impl.dart';
import 'package:trip_mate_mobile/features/coupon/domain/repositories/coupon_repository.dart';
import 'package:trip_mate_mobile/features/coupon/presentation/cubit/create_coupon_cubit.dart';
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
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/travel_group_members_cubit.dart';
import 'package:trip_mate_mobile/features/trip_history/data/datasources/demo_trip_history_store.dart';
import 'package:trip_mate_mobile/features/trip_history/data/repositories/trip_history_repository_impl.dart';
import 'package:trip_mate_mobile/features/trip_history/data/repositories/trip_review_repository_impl.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/repositories/trip_history_repository.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/repositories/trip_review_repository.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/cubit/trip_history_cubit.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/cubit/trip_review_cubit.dart';

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
    ..registerLazySingleton<OperatorRegistrationIdentityService>(
      () => Firebase.apps.isEmpty
          ? const UnavailableOperatorRegistrationIdentityService()
          : FirebaseOperatorRegistrationIdentityService(FirebaseAuth.instance),
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
    ..registerLazySingleton<OperatorApplicationRepository>(
      () => OperatorApplicationRepositoryImpl(serviceLocator()),
    )
    ..registerFactory<FetchOperatorApplication>(
      () => FetchOperatorApplication(serviceLocator()),
    )
    ..registerFactory<ResubmitOperatorApplicationUseCase>(
      () => ResubmitOperatorApplicationUseCase(serviceLocator()),
    )
    ..registerFactory<OperatorApplicationCubit>(
      () => OperatorApplicationCubit(serviceLocator(), serviceLocator()),
    )
    ..registerLazySingleton<TourOperatorRegistrationRepository>(
      () => TourOperatorRegistrationRepositoryImpl(serviceLocator()),
    )
    ..registerFactory<RegisterTourOperator>(
      () => RegisterTourOperator(
        repository: serviceLocator(),
        identityService: serviceLocator(),
        verificationContinueUrl:
            serviceLocator<AppConfig>().requireOperatorVerificationContinueUrl,
      ),
    )
    ..registerLazySingleton<OperatorDocumentPicker>(
      FilePickerOperatorDocumentPicker.new,
    )
    ..registerFactory<RegisterOperatorCubit>(
      () => RegisterOperatorCubit(serviceLocator()),
    )
    ..registerFactory<OperatorEmailRecoveryCubit>(
      () => OperatorEmailRecoveryCubit(serviceLocator()),
    )
    ..registerLazySingleton<PasswordRecoveryRemoteDataSource>(
      () => PasswordRecoveryRemoteDataSourceImpl(serviceLocator()),
    )
    ..registerLazySingleton<PasswordRecoveryRepository>(
      () => PasswordRecoveryRepositoryImpl(serviceLocator()),
    )
    ..registerLazySingleton<TravelGroupRepository>(
      () => TravelGroupRepositoryImpl(dioClient: serviceLocator()),
    )
    ..registerLazySingleton<CouponRemoteDataSource>(
      () => DioCouponRemoteDataSource(serviceLocator()),
    )
    ..registerLazySingleton<CouponRepository>(
      () => CouponRepositoryImpl(serviceLocator()),
    )
    ..registerFactory<CreateCouponCubit>(
      () => CreateCouponCubit(repository: serviceLocator()),
    )
    ..registerLazySingleton<ItineraryRepository>(
      () => ItineraryRepositoryImpl(dioClient: serviceLocator()),
    )
    ..registerLazySingleton<PointOfInterestRepository>(
      () => PointOfInterestRepositoryImpl(dioClient: serviceLocator()),
    )
    ..registerFactory<TravelGroupMembersCubit>(
      () => TravelGroupMembersCubit(repository: serviceLocator()),
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
    )
    ..registerFactory<PasswordRecoveryCubit>(
      () => PasswordRecoveryCubit(serviceLocator()),
    )
    ..registerLazySingleton<DemoTripHistoryStore>(DemoTripHistoryStore.new)
    ..registerFactory<TripHistoryRepository>(
      () => TripHistoryRepositoryImpl(
        dioClient: serviceLocator(),
        demoStore: serviceLocator(),
        isDemoMode: false,
      ),
    )
    ..registerFactory<TripReviewRepository>(
      () => TripReviewRepositoryImpl(
        dioClient: serviceLocator(),
        demoStore: serviceLocator(),
        isDemoMode: false,
      ),
    )
    ..registerFactory<TripHistoryCubit>(
      () => TripHistoryCubit(repository: serviceLocator(), isDemoMode: false),
    )
    ..registerFactory<TripReviewCubit>(
      () => TripReviewCubit(repository: serviceLocator(), isDemoMode: false),
    );
}
