import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

final class AppLoggingInterceptor extends LogInterceptor {
  AppLoggingInterceptor()
    : super(
        requestHeader: false,
        requestBody: false,
        responseHeader: false,
        responseBody: false,
        logPrint: _log,
      );

  static void _log(Object value) {
    if (kDebugMode) {
      debugPrint(value.toString());
    }
  }
}
