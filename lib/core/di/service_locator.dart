import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/core/network/network_info.dart';
import 'package:trip_mate_mobile/core/storage/preferences_service.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:trip_mate_mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:trip_mate_mobile/features/auth/data/services/firebase_auth_service.dart';
import 'package:trip_mate_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/register_cubit.dart';

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
    ..registerLazySingleton<FirebaseAuthService>(
      () => Firebase.apps.isEmpty
          ? const UnavailableFirebaseAuthService()
          : FirebaseAuthServiceImpl(FirebaseAuth.instance, serviceLocator()),
    )
    ..registerLazySingleton<NetworkInfo>(
      () => ConnectivityNetworkInfo(serviceLocator()),
    )
    ..registerLazySingleton<DioClient>(
      () =>
          DioClient(config: serviceLocator(), secureStorage: serviceLocator()),
    )
    ..registerLazySingleton<AuthRemoteDataSource>(
      () => AuthRemoteDataSourceImpl(serviceLocator()),
    )
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(serviceLocator()),
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
