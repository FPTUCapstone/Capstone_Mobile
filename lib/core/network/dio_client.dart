import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/core/constants/api_constants.dart';
import 'package:trip_mate_mobile/core/network/interceptors/auth_interceptor.dart';
import 'package:trip_mate_mobile/core/network/interceptors/logging_interceptor.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';

final class DioClient {
  DioClient({
    required AppConfig config,
    required SecureStorageService secureStorage,
  }) : _dio = Dio(
         BaseOptions(
           baseUrl: config.apiBaseUrl.toString(),
           connectTimeout: ApiConstants.connectTimeout,
           receiveTimeout: ApiConstants.receiveTimeout,
           sendTimeout: ApiConstants.sendTimeout,
           headers: const {
             'Accept': 'application/json',
             'Content-Type': 'application/json',
           },
         ),
       ) {
    _dio.interceptors.add(AuthInterceptor(secureStorage));
    if (config.enableNetworkLogs) {
      _dio.interceptors.add(AppLoggingInterceptor());
    }
  }

  final Dio _dio;

  Dio get dio => _dio;
}
