import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:trip_mate_mobile/core/error/exceptions.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/features/auth/data/models/login_request.dart';
import 'package:trip_mate_mobile/features/auth/data/models/register_traveler_request.dart';
import 'package:trip_mate_mobile/features/auth/data/models/register_traveler_response.dart';
import 'package:trip_mate_mobile/features/auth/data/models/session_response_dto.dart';

abstract interface class AuthRemoteDataSource {
  Future<RegisterTravelerResponse> registerTraveler(
    RegisterTravelerRequest request,
    String firebaseIdToken,
  );

  Future<SessionResponseDto> verifyEmail(String firebaseIdToken);

  Future<SessionResponseDto> googleAuth(String firebaseIdToken);

  Future<SessionResponseDto> login(
    LoginRequest request, [
    String? firebaseIdToken,
  ]);
}

final class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  const AuthRemoteDataSourceImpl(this._dioClient);

  final DioClient _dioClient;

  @override
  Future<RegisterTravelerResponse> registerTraveler(
    RegisterTravelerRequest request,
    String firebaseIdToken,
  ) async {
    try {
      final response = await _dioClient.dio.post<Map<String, dynamic>>(
        '/api/v1/auth/register',
        data: request.toJson(),
        options: Options(
          headers: {'Authorization': 'Bearer $firebaseIdToken'},
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      return RegisterTravelerResponse.fromJson(_unwrap(response.data));
    } on FormatException catch (error) {
      throw ServerException(error.message);
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<SessionResponseDto> verifyEmail(String firebaseIdToken) async {
    try {
      final response = await _dioClient.dio.post<Map<String, dynamic>>(
        '/api/v1/auth/verify-email',
        options: Options(headers: {'Authorization': 'Bearer $firebaseIdToken'}),
      );
      if (kDebugMode) {
        debugPrint(
          '[AUTH-VERIFY] endpoint=/api/v1/auth/verify-email status=${response.statusCode}',
        );
      }
      return SessionResponseDto.fromJson(_unwrap(response.data));
    } on FormatException catch (error) {
      throw ServerException(error.message);
    } on DioException catch (error) {
      throw _mapAndLogAuthError(error);
    }
  }

  @override
  Future<SessionResponseDto> googleAuth(String firebaseIdToken) async {
    try {
      final response = await _dioClient.dio.post<Map<String, dynamic>>(
        '/api/v1/auth/google',
        data: {'idToken': firebaseIdToken},
        options: Options(headers: {'Authorization': 'Bearer $firebaseIdToken'}),
      );
      return SessionResponseDto.fromJson(_unwrap(response.data));
    } on FormatException catch (error) {
      throw ServerException(error.message);
    } on DioException catch (error) {
      throw _handleDioError(error);
    }
  }

  @override
  Future<SessionResponseDto> login(
    LoginRequest request, [
    String? firebaseIdToken,
  ]) async {
    try {
      final response = await _dioClient.dio.post<Map<String, dynamic>>(
        '/api/v1/auth/login',
        data: request.toJson(),
        options: firebaseIdToken == null
            ? null
            : Options(headers: {'Authorization': 'Bearer $firebaseIdToken'}),
      );
      if (kDebugMode) {
        debugPrint(
          '[AUTH-VERIFY] endpoint=/api/v1/auth/login status=${response.statusCode}',
        );
      }
      final data = _unwrap(response.data);
      _logSanitizedAuthenticatedResponse('/api/v1/auth/login', data);
      return SessionResponseDto.fromJson(data);
    } on FormatException catch (error) {
      throw ServerException(error.message);
    } on DioException catch (error) {
      throw _mapAndLogAuthError(error);
    }
  }

  Map<String, dynamic> _unwrap(Map<String, dynamic>? response) {
    final data = response?['data'];
    if (response?['success'] != true || data is! Map<String, dynamic>) {
      throw const FormatException('Invalid API response envelope.');
    }
    return data;
  }

  AppException _handleDioError(DioException error) {
    final response = error.response;
    final statusCode = response?.statusCode;
    String? responseCode;

    if (response?.data is Map<String, dynamic>) {
      final data = response!.data as Map<String, dynamic>;

      final errors = data['errors'];
      responseCode = errors is Map<String, dynamic>
          ? errors['code'] as String?
          : data['code'] as String? ?? data['errorCode'] as String?;
      final knownMessage = _messageForCode(responseCode);
      if (knownMessage != null) {
        return ServerException(knownMessage, responseCode, statusCode);
      }

      if (statusCode == 400 && errors is Map<String, dynamic>) {
        final messages = <String>[];
        for (final entry in errors.entries) {
          if (entry.value is List && (entry.value as List).isNotEmpty) {
            messages.add((entry.value as List).first.toString());
          }
        }
        if (messages.isNotEmpty) {
          return ServerException(messages.join(' '), responseCode, statusCode);
        }
      }
    }

    if (statusCode == 409) {
      return const ServerException(
        'An account with the provided information already exists.',
        null,
        409,
      );
    }

    if (statusCode == 429) {
      return const ServerException(
        'Too many registration attempts. Please try again later.',
        null,
        429,
      );
    }

    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError => const NetworkException(
        'TripMate is temporarily unable to process your request. Please check your connection and try again.',
      ),
      _ => ServerException(
        'TripMate is temporarily unable to process your request. Please check your connection and try again.',
        responseCode,
        statusCode,
      ),
    };
  }

  AppException _mapAndLogAuthError(DioException error) {
    final mappedError = _handleDioError(error);
    if (kDebugMode) {
      final code = mappedError is ServerException ? mappedError.code : null;
      debugPrint(
        '[AUTH-VERIFY] endpoint=${error.requestOptions.path} status=${error.response?.statusCode} code=$code',
      );
    }
    return mappedError;
  }

  void _logSanitizedAuthenticatedResponse(
    String endpoint,
    Map<String, dynamic> data,
  ) {
    if (!kDebugMode) return;
    debugPrint(
      '[AUTH-RESPONSE] endpoint=$endpoint '
      'keys=${data.keys.toList()} '
      'userId=${data['userId']} '
      'role=${data['role']} status=${data['status']} '
      'accessTokenPresent=${data['accessToken'] is String && (data['accessToken'] as String).isNotEmpty} '
      'refreshTokenPresent=${data['refreshToken'] is String && (data['refreshToken'] as String).isNotEmpty}',
    );
  }

  String? _messageForCode(String? code) => switch (code) {
    'AUTH_HEADER_MISSING' =>
      'Unable to register because Firebase authentication is unavailable.',
    'AUTH_TOKEN_INVALID' =>
      'Firebase authentication expired. Please try again.',
    'AUTH_EMAIL_MISMATCH' =>
      'The Firebase account email does not match the registration email.',
    'MSG03' =>
      'An account with this email already exists. Please sign in or use another email.',
    'MSG_PHONE_DUP' => 'This phone number is already registered.',
    'auth.invalid_credentials' =>
      'Invalid email or password. Please try again.',
    'MSG_UNVERIFIED' => 'Please verify your email before signing in.',
    'auth.account_locked' => 'Your account is locked. Please contact support.',
    'auth.account_inactive' =>
      'Your account is inactive. Please contact support.',
    'MSG_EMAIL_NOT_VERIFIED' => 'Please verify your email before continuing.',
    'MSG_USER_NOT_FOUND' => 'Account not found. Please register first.',
    'MSG14' =>
      'The verification link is invalid, expired, or has already been used.',
    'MSG_GOOGLE_TOKEN_INVALID' =>
      'Invalid Google authentication token. Please try again.',
    'AUTH_TOKEN_MISSING' => 'Google authentication is unavailable.',
    'MSG127' => 'Something went wrong. Please try again later.',
    _ => null,
  };
}
