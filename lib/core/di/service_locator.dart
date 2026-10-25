import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/core/location/device_location_service.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/core/network/network_info.dart';
import 'package:trip_mate_mobile/core/network/session_coordinator.dart';
import 'package:trip_mate_mobile/core/push/dio_push_device_repository.dart';
import 'package:trip_mate_mobile/core/push/push_device_coordinator.dart';
import 'package:trip_mate_mobile/core/push/push_device_repository.dart';
import 'package:trip_mate_mobile/core/push/trip_push_messaging.dart';
import 'package:trip_mate_mobile/core/storage/preferences_service.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/auth/change_password/data/datasources/change_password_remote_data_source.dart';
import 'package:trip_mate_mobile/features/auth/change_password/data/repositories/change_password_repository_impl.dart';
import 'package:trip_mate_mobile/features/auth/change_password/domain/repositories/change_password_repository.dart';
import 'package:trip_mate_mobile/features/auth/change_password/presentation/cubit/change_password_cubit.dart';
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
import 'package:trip_mate_mobile/features/booking/data/datasources/booking_remote_data_source.dart';
import 'package:trip_mate_mobile/features/booking/data/repositories/booking_repository_impl.dart';
import 'package:trip_mate_mobile/features/booking/domain/repositories/booking_repository.dart';
import 'package:trip_mate_mobile/features/booking/domain/usecases/create_booking_use_case.dart';
import 'package:trip_mate_mobile/features/booking/domain/usecases/get_booking_contact_use_case.dart';
import 'package:trip_mate_mobile/features/booking/domain/usecases/quote_booking_use_case.dart';
import 'package:trip_mate_mobile/features/booking/presentation/cubit/book_tour_cubit.dart';
import 'package:trip_mate_mobile/features/booking_refund/data/datasources/booking_refund_remote_data_source.dart';
import 'package:trip_mate_mobile/features/booking_refund/data/repositories/booking_refund_repository_impl.dart';
import 'package:trip_mate_mobile/features/booking_refund/domain/repositories/booking_refund_repository.dart';
import 'package:trip_mate_mobile/features/booking_refund/domain/usecases/get_booking_refund_progress_use_case.dart';
import 'package:trip_mate_mobile/features/booking_refund/presentation/cubit/booking_refund_progress_cubit.dart';
import 'package:trip_mate_mobile/features/coupon/data/datasources/coupon_remote_data_source.dart';
import 'package:trip_mate_mobile/features/coupon/data/repositories/coupon_repository_impl.dart';
import 'package:trip_mate_mobile/features/coupon/domain/repositories/coupon_repository.dart';
import 'package:trip_mate_mobile/features/coupon/presentation/cubit/create_coupon_cubit.dart';
import 'package:trip_mate_mobile/features/e_ticket/data/repositories/e_ticket_repository_impl.dart';
import 'package:trip_mate_mobile/features/e_ticket/domain/repositories/e_ticket_repository.dart';
import 'package:trip_mate_mobile/features/e_ticket/domain/usecases/get_e_ticket_use_case.dart';
import 'package:trip_mate_mobile/features/e_ticket/domain/usecases/refresh_e_ticket_qr_use_case.dart';
import 'package:trip_mate_mobile/features/e_ticket/presentation/cubit/e_ticket_cubit.dart';
import 'package:trip_mate_mobile/features/operator_tours/data/datasources/operator_tour_remote_data_source.dart';
import 'package:trip_mate_mobile/features/operator_tours/data/repositories/operator_tour_repository_impl.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/repositories/operator_tour_repository.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/usecases/create_tour_package_use_case.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/usecases/load_tour_package_options_use_case.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/usecases/tour_package_use_cases.dart';
import 'package:trip_mate_mobile/features/operator_tours/presentation/cubit/create_tour_package_cubit.dart';
import 'package:trip_mate_mobile/features/operator_tours/presentation/cubit/operator_tours_cubit.dart';
import 'package:trip_mate_mobile/features/operator_tours/presentation/services/tour_image_picker.dart';
import 'package:trip_mate_mobile/features/payment/data/datasources/payment_remote_data_source.dart';
import 'package:trip_mate_mobile/features/payment/data/repositories/payment_repository_impl.dart';
import 'package:trip_mate_mobile/features/payment/domain/repositories/payment_repository.dart';
import 'package:trip_mate_mobile/features/payment/domain/usecases/cancel_payment_use_case.dart';
import 'package:trip_mate_mobile/features/payment/domain/usecases/complete_mock_payment_use_case.dart';
import 'package:trip_mate_mobile/features/payment/domain/usecases/create_or_reuse_payment_use_case.dart';
import 'package:trip_mate_mobile/features/payment/domain/usecases/get_booking_payment_status_use_case.dart';
import 'package:trip_mate_mobile/features/payment/presentation/cubit/payment_cubit.dart';
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
import 'package:trip_mate_mobile/features/tour_detail/data/datasources/dio_tour_detail_remote_data_source.dart';
import 'package:trip_mate_mobile/features/tour_detail/data/datasources/tour_detail_data_source.dart';
import 'package:trip_mate_mobile/features/tour_detail/data/repositories/tour_detail_repository_impl.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/repositories/tour_detail_repository.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/usecases/get_tour_detail.dart';
import 'package:trip_mate_mobile/features/tour_detail/presentation/cubit/tour_detail_cubit.dart';
import 'package:trip_mate_mobile/features/tour_recommendations/data/datasources/tour_recommendations_data_source.dart';
import 'package:trip_mate_mobile/features/tour_recommendations/data/repositories/tour_recommendations_repository_impl.dart';
import 'package:trip_mate_mobile/features/tour_recommendations/domain/repositories/tour_recommendations_repository.dart';
import 'package:trip_mate_mobile/features/tour_recommendations/domain/usecases/get_tour_recommendations.dart';
import 'package:trip_mate_mobile/features/tour_recommendations/presentation/cubit/tour_recommendations_cubit.dart';
import 'package:trip_mate_mobile/features/tour_search/data/datasources/tour_search_remote_data_source.dart';
import 'package:trip_mate_mobile/features/tour_search/data/repositories/tour_search_repository_impl.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/repositories/tour_search_repository.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/usecases/search_tours_use_case.dart';
import 'package:trip_mate_mobile/features/tour_search/presentation/cubit/tour_search_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/data/datasources/travel_preferences_remote_data_source.dart';
import 'package:trip_mate_mobile/features/traveler/data/repositories/external_review_repository_impl.dart';
import 'package:trip_mate_mobile/features/traveler/data/repositories/itinerary_repository_impl.dart';
import 'package:trip_mate_mobile/features/traveler/data/repositories/mapbox_directions_repository_impl.dart';
import 'package:trip_mate_mobile/features/traveler/data/repositories/mapbox_search_box_repository_impl.dart';
import 'package:trip_mate_mobile/features/traveler/data/repositories/navigation_session_repository_impl.dart';
import 'package:trip_mate_mobile/features/traveler/data/repositories/point_of_interest_repository_impl.dart';
import 'package:trip_mate_mobile/features/traveler/data/repositories/travel_group_repository_impl.dart';
import 'package:trip_mate_mobile/features/traveler/data/repositories/travel_preferences_repository_impl.dart';
import 'package:trip_mate_mobile/features/traveler/data/services/geolocator_navigation_location_tracker.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/address_search_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/external_review_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/itinerary_list_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/itinerary_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/itinerary_suggestion_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/leave_travel_group_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/navigation_session_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/point_of_interest_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/route_directions_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/travel_group_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/travel_preferences_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/trip_alert_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/services/navigation_location_tracker.dart';
import 'package:trip_mate_mobile/features/traveler/domain/services/weather_advisory_session_store.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/address_search_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/my_trips_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/travel_group_members_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/travel_preferences_cubit.dart';
import 'package:trip_mate_mobile/features/trip_history/data/datasources/demo_trip_history_store.dart';
import 'package:trip_mate_mobile/features/trip_history/data/repositories/canonical_trip_review_repository_impl.dart';
import 'package:trip_mate_mobile/features/trip_history/data/repositories/demo_trip_records_repository.dart';
import 'package:trip_mate_mobile/features/trip_history/data/repositories/trip_history_repository_impl.dart';
import 'package:trip_mate_mobile/features/trip_history/data/repositories/trip_records_repository_impl.dart';
import 'package:trip_mate_mobile/features/trip_history/data/repositories/trip_review_repository_impl.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/reviewable_record_ref.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_record.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/repositories/canonical_trip_review_repository.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/repositories/trip_history_repository.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/repositories/trip_records_repository.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/repositories/trip_review_repository.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/usecases/canonical_trip_review_use_case.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/usecases/trip_records_use_case.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/cubit/canonical_trip_review_cubit.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/cubit/trip_history_cubit.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/cubit/trip_record_detail_cubit.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/cubit/trip_records_cubit.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/cubit/trip_review_cubit.dart';

final GetIt serviceLocator = GetIt.instance;

/// The registered [T], or null when it is not registered (e.g. in widget
/// tests or before configuration).
T? locateOptional<T extends Object>() =>
    serviceLocator.isRegistered<T>() ? serviceLocator<T>() : null;

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
    ..registerLazySingleton<PushDeviceRepository>(
      () => DioPushDeviceRepository(serviceLocator()),
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
    // ── Tour Recommendations ───────────────────────────────────────────
    ..registerLazySingleton<TourRecommendationsDataSource>(
      () => const PendingTourRecommendationsDataSource(),
    )
    ..registerLazySingleton<TourRecommendationsRepository>(
      () => TourRecommendationsRepositoryImpl(serviceLocator()),
    )
    ..registerFactory<GetTourRecommendations>(
      () => GetTourRecommendations(serviceLocator()),
    )
    ..registerFactory<TourRecommendationsCubit>(
      () => TourRecommendationsCubit(getTourRecommendations: serviceLocator()),
    )
    // ── Tour Detail ────────────────────────────────────────────────────
    ..registerLazySingleton<TourDetailDataSource>(
      () => DioTourDetailRemoteDataSource(serviceLocator()),
    )
    ..registerLazySingleton<TourDetailRepository>(
      () => TourDetailRepositoryImpl(serviceLocator()),
    )
    ..registerFactory<GetTourDetail>(() => GetTourDetail(serviceLocator()))
    ..registerFactory<TourDetailCubit>(
      () => TourDetailCubit(getTourDetail: serviceLocator()),
    )
    ..registerLazySingleton<OperatorTourRemoteDataSource>(
      () => DioOperatorTourRemoteDataSource(serviceLocator()),
    )
    ..registerLazySingleton<OperatorTourRepository>(
      () => OperatorTourRepositoryImpl(serviceLocator()),
    )
    ..registerFactory<CreateTourPackageUseCase>(
      () => CreateTourPackageUseCase(serviceLocator()),
    )
    ..registerFactory<LoadTourPackageOptionsUseCase>(
      () => LoadTourPackageOptionsUseCase(serviceLocator()),
    )
    ..registerFactory<ListTourPackagesUseCase>(
      () => ListTourPackagesUseCase(serviceLocator()),
    )
    ..registerFactory<GetTourPackageUseCase>(
      () => GetTourPackageUseCase(serviceLocator()),
    )
    ..registerFactory<UpdateTourPackageUseCase>(
      () => UpdateTourPackageUseCase(serviceLocator()),
    )
    ..registerFactory<SubmitTourForReviewUseCase>(
      () => SubmitTourForReviewUseCase(serviceLocator()),
    )
    ..registerFactory<ManageTourMediaUseCase>(
      () => ManageTourMediaUseCase(serviceLocator()),
    )
    ..registerLazySingleton<TourImagePicker>(FilePickerTourImagePicker.new)
    ..registerFactory<OperatorToursCubit>(
      () => OperatorToursCubit(listTours: serviceLocator()),
    )
    ..registerFactory<CreateTourPackageCubit>(
      () => CreateTourPackageCubit(
        createTour: serviceLocator(),
        loadOptions: serviceLocator(),
        getTour: serviceLocator(),
        updateTour: serviceLocator(),
        submitForReview: serviceLocator(),
        media: serviceLocator(),
        getPoiDetail: serviceLocator(),
        imagePicker: serviceLocator(),
      ),
    )
    ..registerLazySingleton<BookingRemoteDataSource>(
      () => DioBookingRemoteDataSource(serviceLocator()),
    )
    ..registerLazySingleton<BookingRepository>(
      () => BookingRepositoryImpl(serviceLocator()),
    )
    ..registerFactory<QuoteBookingUseCase>(
      () => QuoteBookingUseCase(serviceLocator()),
    )
    ..registerFactory<CreateBookingUseCase>(
      () => CreateBookingUseCase(serviceLocator()),
    )
    ..registerFactory<GetBookingContactUseCase>(
      () => GetBookingContactUseCase(serviceLocator()),
    )
    ..registerFactoryParam<BookTourCubit, String, void>(
      (tourScheduleId, _) => BookTourCubit(
        tourScheduleId: tourScheduleId,
        quoteBooking: serviceLocator(),
        createBooking: serviceLocator(),
        getBookingContact: serviceLocator(),
      ),
    )
    ..registerLazySingleton<PaymentRemoteDataSource>(
      () => DioPaymentRemoteDataSource(serviceLocator()),
    )
    ..registerLazySingleton<PaymentRepository>(
      () => PaymentRepositoryImpl(serviceLocator()),
    )
    ..registerFactory<CreateOrReusePaymentUseCase>(
      () => CreateOrReusePaymentUseCase(serviceLocator()),
    )
    ..registerFactory<GetBookingPaymentStatusUseCase>(
      () => GetBookingPaymentStatusUseCase(serviceLocator()),
    )
    ..registerFactory<CompleteMockPaymentUseCase>(
      () => CompleteMockPaymentUseCase(serviceLocator()),
    )
    ..registerFactory<CancelPaymentUseCase>(
      () => CancelPaymentUseCase(serviceLocator()),
    )
    ..registerFactory<PaymentCubit>(
      () => PaymentCubit(
        createOrReusePayment: serviceLocator(),
        getBookingPaymentStatus: serviceLocator(),
        completeMockPayment: serviceLocator(),
        cancelPayment: serviceLocator(),
      ),
    )
    ..registerLazySingleton<BookingRefundRemoteDataSource>(
      () => DioBookingRefundRemoteDataSource(serviceLocator()),
    )
    ..registerLazySingleton<BookingRefundRepository>(
      () => BookingRefundRepositoryImpl(serviceLocator()),
    )
    ..registerFactory<GetBookingRefundProgressUseCase>(
      () => GetBookingRefundProgressUseCase(serviceLocator()),
    )
    ..registerFactory<BookingRefundProgressCubit>(
      () => BookingRefundProgressCubit(getProgress: serviceLocator()),
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
    ..registerLazySingleton<ChangePasswordRemoteDataSource>(
      () => ChangePasswordRemoteDataSourceImpl(serviceLocator()),
    )
    ..registerLazySingleton<ChangePasswordRepository>(
      () => ChangePasswordRepositoryImpl(serviceLocator()),
    )
    ..registerFactory<ChangePasswordCubit>(
      () => ChangePasswordCubit(serviceLocator(), serviceLocator()),
    )
    ..registerLazySingleton<TravelPreferencesRemoteDataSource>(
      () => TravelPreferencesRemoteDataSourceImpl(serviceLocator()),
    )
    ..registerLazySingleton<TravelPreferencesRepository>(
      () => TravelPreferencesRepositoryImpl(serviceLocator()),
    )
    ..registerFactory<TravelPreferencesCubit>(
      () => TravelPreferencesCubit(serviceLocator()),
    )
    ..registerLazySingleton<TravelGroupRepositoryImpl>(
      () => TravelGroupRepositoryImpl(dioClient: serviceLocator()),
    )
    ..registerLazySingleton<TravelGroupRepository>(
      () => serviceLocator<TravelGroupRepositoryImpl>(),
    )
    ..registerLazySingleton<LeaveTravelGroupRepository>(
      () => serviceLocator<TravelGroupRepositoryImpl>(),
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
    ..registerLazySingleton<ItineraryListRepository>(
      () => ItineraryRepositoryImpl(dioClient: serviceLocator()),
    )
    ..registerLazySingleton<ItinerarySuggestionRepository>(
      () => ItineraryRepositoryImpl(dioClient: serviceLocator()),
    )
    ..registerLazySingleton<ExternalReviewRepository>(
      () => ExternalReviewRepositoryImpl(dioClient: serviceLocator()),
    )
    ..registerFactory<MyTripsCubit>(
      () => MyTripsCubit(repository: serviceLocator()),
    )
    ..registerLazySingleton<PointOfInterestRepository>(
      () => PointOfInterestRepositoryImpl(dioClient: serviceLocator()),
    )
    ..registerLazySingleton<NavigationSessionRepository>(
      () => NavigationSessionRepositoryImpl(dioClient: serviceLocator()),
    )
    ..registerLazySingleton<TripAlertRepository>(
      () => NavigationSessionRepositoryImpl(dioClient: serviceLocator()),
    )
    ..registerLazySingleton<RouteDirectionsRepository>(() {
      final token = serviceLocator<AppConfig>().mapboxAccessToken;
      return token == null
          ? const UnavailableRouteDirectionsRepository()
          : MapboxDirectionsRepositoryImpl(accessToken: token);
    })
    ..registerLazySingleton<AddressSearchRepository>(() {
      final token = serviceLocator<AppConfig>().mapboxAccessToken;
      return token == null
          ? const UnavailableAddressSearchRepository()
          : MapboxSearchBoxRepositoryImpl(accessToken: token);
    })
    ..registerFactory<AddressSearchCubit>(
      () => AddressSearchCubit(repository: serviceLocator()),
    )
    ..registerLazySingleton<NavigationLocationTracker>(
      GeolocatorNavigationLocationTracker.new,
    )
    ..registerLazySingleton<WeatherAdvisorySessionStore>(
      WeatherAdvisorySessionStore.new,
    )
    ..registerFactory<TravelGroupMembersCubit>(
      () => TravelGroupMembersCubit(repository: serviceLocator()),
    )
    ..registerFactory<AuthSessionCubit>(
      () => AuthSessionCubit(
        serviceLocator(),
        serviceLocator(),
        serviceLocator(),
        serviceLocator.isRegistered<PushDeviceLifecycle>()
            ? serviceLocator<PushDeviceLifecycle>()
            : null,
      ),
    )
    ..registerFactory<RegisterCubit>(
      () => RegisterCubit(serviceLocator(), serviceLocator()),
    )
    ..registerFactory<PasswordRecoveryCubit>(
      () => PasswordRecoveryCubit(serviceLocator()),
    )
    ..registerLazySingleton<DemoTripHistoryStore>(DemoTripHistoryStore.new)
    ..registerLazySingleton<CanonicalTripReviewRepository>(
      () => CanonicalTripReviewRepositoryImpl(serviceLocator()),
    )
    ..registerLazySingleton<CanonicalTripReviewUseCase>(
      () => CanonicalTripReviewUseCase(serviceLocator()),
    )
    ..registerFactoryParam<CanonicalTripReviewCubit, ReviewableRecordRef, void>(
      (reference, _) => CanonicalTripReviewCubit(
        reference: reference,
        useCase: serviceLocator(),
      ),
    )
    ..registerFactoryParam<TripHistoryRepository, bool, void>(
      (isDemoMode, _) => TripHistoryRepositoryImpl(
        demoStore: isDemoMode ? serviceLocator<DemoTripHistoryStore>() : null,
        isDemoMode: isDemoMode,
      ),
    )
    // UC-29 e-ticket
    ..registerLazySingleton<ETicketRepository>(
      () => ETicketRepositoryImpl(serviceLocator()),
    )
    ..registerFactory<GetETicketUseCase>(
      () => GetETicketUseCase(serviceLocator()),
    )
    ..registerFactory<RefreshETicketQrUseCase>(
      () => RefreshETicketQrUseCase(serviceLocator()),
    )
    ..registerFactoryParam<ETicketCubit, ETicketKey, void>(
      (key, _) => ETicketCubit(
        key: key,
        getTicket: serviceLocator(),
        refreshQr: serviceLocator(),
        networkInfo: serviceLocator(),
      ),
    )
    ..registerFactoryParam<TripRecordsRepository, bool, void>(
      (isDemoMode, _) => isDemoMode
          ? const DemoTripRecordsRepository()
          : TripRecordsRepositoryImpl(serviceLocator()),
    )
    ..registerFactoryParam<TripRecordsUseCase, bool, void>(
      (isDemoMode, _) => TripRecordsUseCase(serviceLocator(param1: isDemoMode)),
    )
    ..registerFactoryParam<TripRecordsCubit, bool, void>(
      (isDemoMode, _) =>
          TripRecordsCubit(useCase: serviceLocator(param1: isDemoMode)),
    )
    ..registerFactoryParam<TripRecordDetailCubit, TripRecordRef, bool>(
      (reference, isDemoMode) => TripRecordDetailCubit(
        useCase: serviceLocator(param1: isDemoMode),
        reference: reference,
      ),
    )
    ..registerFactoryParam<TripReviewRepository, bool, void>(
      (isDemoMode, _) => TripReviewRepositoryImpl(
        demoStore: isDemoMode ? serviceLocator<DemoTripHistoryStore>() : null,
        isDemoMode: isDemoMode,
      ),
    )
    ..registerFactoryParam<TripHistoryCubit, bool, void>(
      (isDemoMode, _) => TripHistoryCubit(
        repository: serviceLocator(param1: isDemoMode),
        isDemoMode: isDemoMode,
        demoTravelerId: isDemoMode ? DemoTripHistoryStore.demoTravelerId : null,
      ),
    )
    ..registerFactoryParam<TripReviewCubit, bool, void>(
      (isDemoMode, _) => TripReviewCubit(
        repository: serviceLocator(param1: isDemoMode),
        historyRepository: serviceLocator(param1: isDemoMode),
        isDemoMode: isDemoMode,
      ),
    );

  if (Firebase.apps.isNotEmpty) {
    serviceLocator
      ..registerLazySingleton<TripPushMessaging>(
        () => FirebaseTripPushMessaging(FirebaseMessaging.instance),
      )
      ..registerLazySingleton<PushDeviceCoordinator>(
        () => PushDeviceCoordinator(
          repository: serviceLocator(),
          storage: serviceLocator(),
          messaging: serviceLocator(),
        ),
      )
      ..registerLazySingleton<PushDeviceLifecycle>(
        () => serviceLocator<PushDeviceCoordinator>(),
      );
  }
}
