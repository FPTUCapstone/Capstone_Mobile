import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/constants/api_constants.dart';
import 'package:trip_mate_mobile/core/error/exceptions.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/features/auth/data/mappers/operator_registration_mapper.dart';
import 'package:trip_mate_mobile/features/auth/data/models/login_request.dart';
import 'package:trip_mate_mobile/features/auth/data/models/register_operator_response.dart';
import 'package:trip_mate_mobile/features/auth/data/models/register_traveler_request.dart';
import 'package:trip_mate_mobile/features/auth/data/models/register_traveler_response.dart';
import 'package:trip_mate_mobile/features/auth/data/models/session_response_dto.dart';
import 'package:trip_mate_mobile/features/auth/data/models/sign_out_request.dart';

abstract interface class AuthRemoteDataSource {
  Future<RegisterOperatorResponse> registerOperator(FormData formData);

  Future<void> confirmOperatorEmail(String firebaseIdToken);

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

  Future<void> logout(String? refreshToken);
}

final class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  const AuthRemoteDataSourceImpl(this._dioClient);

  final DioClient _dioClient;

  @override
  Future<void> confirmOperatorEmail(String firebaseIdToken) async {
    try {
      final response = await _dioClient.dio.post<Map<String, dynamic>>(
        '/api/v1/auth/web/verify-email',
        options: Options(
          headers: {'Authorization': 'Bearer $firebaseIdToken'},
          extra: const {'skipAuth': true},
        ),
      );
      final body = response.data;
      if (response.statusCode != 200 ||
          body?['success'] != true ||
          body?['data'] is! Map<String, dynamic> ||
          (body!['data'] as Map<String, dynamic>)['emailVerified'] != true) {
        throw const OperatorVerificationRemoteUnknown();
      }
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 400 || status == 401 || status == 403 || status == 503) {
        throw OperatorVerificationRemoteRejection(error.response?.data);
      }
      throw const OperatorVerificationRemoteUnknown();
    } on TypeError {
      throw const OperatorVerificationRemoteUnknown();
    }
  }

  @override
  Future<RegisterOperatorResponse> registerOperator(FormData formData) async {
    try {
      final response = await _dioClient.dio.post<Map<String, dynamic>>(
        '/api/v1/auth/register/operator',
        data: formData,
        options: Options(
          contentType: Headers.multipartFormDataContentType,
          receiveTimeout: ApiConstants.operatorRegistrationReceiveTimeout,
          extra: const {'skipAuth': true},
        ),
      );
      return RegisterOperatorResponse.fromEnvelope(
        response.statusCode,
        response.data,
      );
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 400 ||
          status == 401 ||
          status == 409 ||
          status == 413 ||
          status == 415 ||
          status == 503) {
        throw OperatorRegistrationRemoteRejection(
          status!,
          error.response?.data,
        );
      }
      throw const OperatorRegistrationRemoteUnknown();
    } on FormatException {
      throw const OperatorRegistrationRemoteUnknown();
    } on TypeError {
      throw const OperatorRegistrationRemoteUnknown();
    }
  }

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
    } on FormatException {
      throw const ServerException('Đã có lỗi xảy ra. Vui lòng thử lại.');
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (error) {
      if (error is AppException) rethrow;
      throw const ServerException('Đã có lỗi xảy ra. Vui lòng thử lại.');
    }
  }

  @override
  Future<SessionResponseDto> verifyEmail(String firebaseIdToken) async {
    try {
      final response = await _dioClient.dio.post<Map<String, dynamic>>(
        '/api/v1/auth/verify-email',
        options: Options(headers: {'Authorization': 'Bearer $firebaseIdToken'}),
      );
      return SessionResponseDto.fromJson(_unwrap(response.data));
    } on FormatException {
      throw const ServerException(
        'Không thể hoàn tất đăng nhập. Vui lòng thử lại.',
      );
    } on DioException catch (error) {
      throw _handleDioError(error);
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
    } on FormatException {
      throw const ServerException(
        'Không thể hoàn tất đăng nhập. Vui lòng thử lại.',
      );
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
      final data = _unwrap(response.data);
      return SessionResponseDto.fromJson(data);
    } on FormatException {
      throw const ServerException(
        'Không thể hoàn tất đăng nhập. Vui lòng thử lại.',
      );
    } on DioException catch (error) {
      throw _handleDioError(error);
    }
  }

  @override
  Future<void> logout(String? refreshToken) => _signOut(refreshToken);

  Future<void> _signOut(String? refreshToken) async {
    try {
      final response = await _dioClient.dio.post<Map<String, dynamic>>(
        '/api/v1/auth/logout',
        data: SignOutRequest(refreshToken: refreshToken).toJson(),
      );
      _unwrapSignOut(response.data);
    } on FormatException {
      throw const ServerException('Đã có lỗi xảy ra. Vui lòng thử lại.');
    } on DioException catch (error) {
      throw _handleDioError(error);
    } catch (error) {
      if (error is AppException) rethrow;
      throw const ServerException('Đã có lỗi xảy ra. Vui lòng thử lại.');
    }
  }

  void _unwrapSignOut(Map<String, dynamic>? response) {
    if (response?['success'] != true || response?['data'] != true) {
      throw const FormatException('Invalid sign-out response envelope.');
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

      if (statusCode == 400) {
        return ServerException(
          'Không thể hoàn tất yêu cầu. Vui lòng thử lại.',
          responseCode,
          statusCode,
        );
      }
    }

    if (statusCode == 409) {
      return const ServerException(
        'Tài khoản với thông tin này đã tồn tại.',
        null,
        409,
      );
    }

    if (statusCode == 429) {
      return const ServerException(
        'Bạn thao tác đăng ký quá nhiều lần. Vui lòng thử lại sau.',
        null,
        429,
      );
    }

    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError => const NetworkException(
        'TripMate tạm thời không thể xử lý yêu cầu của bạn. Vui lòng kiểm tra kết nối mạng và thử lại.',
      ),
      _ => ServerException(
        'TripMate tạm thời không thể xử lý yêu cầu của bạn. Vui lòng kiểm tra kết nối mạng và thử lại.',
        responseCode,
        statusCode,
      ),
    };
  }

  String? _messageForCode(String? code) => switch (code) {
    'AUTH_HEADER_MISSING' =>
      'Không thể đăng ký do dịch vụ xác thực Firebase hiện không khả dụng.',
    'AUTH_TOKEN_INVALID' =>
      'Phiên xác thực Firebase đã hết hạn. Vui lòng thử lại.',
    'AUTH_EMAIL_MISMATCH' =>
      'Email tài khoản Firebase không khớp với email đăng ký.',
    'MSG03' =>
      'Email này đã được sử dụng. Vui lòng đăng nhập hoặc dùng email khác.',
    'MSG_PHONE_DUP' => 'Số điện thoại này đã được đăng ký.',
    'auth.invalid_credentials' =>
      'Email hoặc mật khẩu không đúng. Vui lòng thử lại.',
    'MSG_UNVERIFIED' => 'Vui lòng xác minh email trước khi đăng nhập.',
    'auth.account_locked' =>
      'Tài khoản của bạn đã bị khóa. Vui lòng liên hệ bộ phận hỗ trợ.',
    'auth.account_inactive' =>
      'Tài khoản của bạn chưa được kích hoạt. Vui lòng liên hệ bộ phận hỗ trợ.',
    'auth.account_state_unresolved' =>
      'Không thể xác nhận trạng thái tài khoản của bạn. Nếu bạn vừa đăng ký, hãy xác minh email; nếu không, vui lòng liên hệ hỗ trợ TripMate.',
    'auth.admin_google_sign_in_disabled' =>
      'Tài khoản quản trị viên chỉ hỗ trợ đăng nhập trên nền tảng Web.',
    'auth.admin_mobile_sign_in_disabled' =>
      'Tài khoản quản trị viên chỉ hỗ trợ đăng nhập trên nền tảng Web.',
    'MSG_EMAIL_NOT_VERIFIED' => 'Vui lòng xác minh email trước khi tiếp tục.',
    'MSG_USER_NOT_FOUND' => 'Không tìm thấy tài khoản. Vui lòng đăng ký trước.',
    'MSG14' =>
      'Liên kết xác minh không hợp lệ, đã hết hạn hoặc đã được sử dụng.',
    'MSG_GOOGLE_TOKEN_INVALID' =>
      'Mã xác thực Google không hợp lệ. Vui lòng thử lại.',
    'AUTH_TOKEN_MISSING' =>
      'Dịch vụ đăng nhập bằng Google hiện không khả dụng.',
    'MSG127' => 'Đã có lỗi xảy ra. Vui lòng thử lại sau.',
    _ => null,
  };
}
