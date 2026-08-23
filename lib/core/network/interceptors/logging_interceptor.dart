import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

final class AppLoggingInterceptor extends LogInterceptor {
  AppLoggingInterceptor()
    : super(requestBody: true, responseBody: true, logPrint: _log);

  static void _log(Object value) {
    if (kDebugMode) {
      debugPrint(value.toString());
    }
  }
}
