import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/features/tour_operator/domain/entities/operator_profile.dart';
import 'package:trip_mate_mobile/features/tour_operator/domain/repositories/operator_profile_repository.dart';

abstract interface class OperatorProfileRemoteDataSource {
  Future<OperatorProfile> getProfile();

  Future<OperatorProfile> updateProfile(UpdateOperatorProfileInput input);
}

final class DioOperatorProfileRemoteDataSource
    implements OperatorProfileRemoteDataSource {
  const DioOperatorProfileRemoteDataSource(this._dio);

  static const _profilePath = '/api/v1/operator/profile';

  final Dio _dio;

  @override
  Future<OperatorProfile> getProfile() async {
    try {
      final response = await _dio.get<dynamic>(_profilePath);
      return _parseProfile(response.data);
    } on DioException catch (error) {
      throw _mapDioException(error, isMutation: false);
    } on OperatorProfileFailureException {
      rethrow;
    } on Object {
      throw const OperatorProfileFailureException(
        kind: OperatorProfileFailureKind.unknown,
        message: OperatorProfileMessages.systemFailure,
      );
    }
  }

  @override
  Future<OperatorProfile> updateProfile(
    UpdateOperatorProfileInput input,
  ) async {
    final normalized = input.normalized();
    final fields = <String, dynamic>{
      'businessName': normalized.businessName,
      'businessDescription': normalized.businessDescription,
      'businessAddress': normalized.businessAddress,
      'contactPhone': normalized.contactPhone,
      'contactEmail': normalized.contactEmail,
      'website': normalized.website,
    };

    // Mutual exclusion: never send both logo and removeLogo=true.
    if (normalized.logo != null) {
      final logo = normalized.logo!;
      fields['logo'] = MultipartFile.fromBytes(
        logo.bytes,
        filename: logo.fileName,
        contentType: DioMediaType.parse(logo.mimeType),
      );
    } else if (normalized.removeLogo) {
      fields['removeLogo'] = 'true';
    }

    try {
      final response = await _dio.put<dynamic>(
        _profilePath,
        data: FormData.fromMap(fields),
      );
      final data = response.data;
      if (data is Map && data['profile'] is Map) {
        return _parseProfile(data['profile']);
      }
      // Fallback: if 200 PUT omitted the profile object, fetch the latest copy.
      return await getProfile();
    } on DioException catch (error) {
      throw _mapDioException(error, isMutation: true);
    } on OperatorProfileValidationException {
      rethrow;
    } on OperatorProfileFailureException {
      rethrow;
    } on Object {
      throw const OperatorProfileFailureException(
        kind: OperatorProfileFailureKind.unknown,
        message: OperatorProfileMessages.systemFailure,
      );
    }
  }

  OperatorProfile _parseProfile(dynamic raw) {
    if (raw is! Map) {
      throw const OperatorProfileFailureException(
        kind: OperatorProfileFailureKind.unknown,
        message: OperatorProfileMessages.systemFailure,
      );
    }
    final data = Map<String, dynamic>.from(raw);
    final rawUserId = data['userId'];
    final userId = rawUserId is int
        ? rawUserId
        : int.tryParse(rawUserId?.toString() ?? '') ?? 0;
    final rawWebsite = data['website'] as String?;
    final rawLogoUrl = data['logoUrl'] as String?;

    return OperatorProfile(
      userId: userId,
      businessName: (data['businessName'] as String?) ?? '',
      businessDescription: (data['businessDescription'] as String?) ?? '',
      businessAddress: (data['businessAddress'] as String?) ?? '',
      contactPhone: (data['contactPhone'] as String?) ?? '',
      contactEmail: (data['contactEmail'] as String?) ?? '',
      website: rawWebsite != null && rawWebsite.isNotEmpty ? rawWebsite : null,
      logoUrl: rawLogoUrl != null && rawLogoUrl.isNotEmpty ? rawLogoUrl : null,
      businessLicenceNumber: (data['businessLicenceNumber'] as String?) ?? '',
      taxCode: (data['taxCode'] as String?) ?? '',
      approvalStatus: (data['approvalStatus'] as String?) ?? 'Approved',
      accountEmail: (data['accountEmail'] as String?) ?? '',
    );
  }

  Exception _mapDioException(DioException error, {required bool isMutation}) {
    final status = error.response?.statusCode;
    final body = error.response?.data is Map
        ? Map<String, dynamic>.from(error.response!.data as Map)
        : null;
    final errorCode = _readErrorCode(body);

    if (status == 401) {
      return OperatorProfileFailureException(
        kind: OperatorProfileFailureKind.unauthorized,
        message: OperatorProfileMessages.sessionExpired,
        errorCode: errorCode,
      );
    }

    if (status == 403) {
      return OperatorProfileFailureException(
        kind: OperatorProfileFailureKind.forbidden,
        message: OperatorProfileMessages.notApprovedOperator,
        errorCode: errorCode,
      );
    }

    if (isMutation) {
      if (status == 413) {
        return const OperatorProfileValidationException(
          OperatorProfileValidationErrors(
            logo: OperatorProfileMessages.invalidLogo,
          ),
        );
      }

      if (status == 400) {
        final fieldErrors = _extractFieldErrors(body?['errors']);
        if (fieldErrors != null && fieldErrors.isNotEmpty) {
          return OperatorProfileValidationException(fieldErrors);
        }
        return const OperatorProfileValidationException(
          OperatorProfileValidationErrors(
            logo: OperatorProfileMessages.invalidLogo,
          ),
        );
      }
    }

    if (status == 404) {
      return OperatorProfileFailureException(
        kind: OperatorProfileFailureKind.notFound,
        message: OperatorProfileMessages.systemFailure,
        errorCode: errorCode,
      );
    }

    if (status == 503) {
      return OperatorProfileFailureException(
        kind: OperatorProfileFailureKind.unavailable,
        message: OperatorProfileMessages.systemFailure,
        errorCode: errorCode,
      );
    }

    return OperatorProfileFailureException(
      kind: OperatorProfileFailureKind.unknown,
      message: OperatorProfileMessages.systemFailure,
      errorCode: errorCode,
    );
  }

  String? _readErrorCode(Map<String, dynamic>? body) {
    if (body == null) return null;
    if (body['errorCode'] is String) return body['errorCode'] as String;
    if (body['code'] is String) return body['code'] as String;
    final ext = body['extensions'];
    if (ext is Map && ext['errorCode'] is String) {
      return ext['errorCode'] as String;
    }
    return null;
  }

  OperatorProfileValidationErrors? _extractFieldErrors(dynamic rawErrors) {
    if (rawErrors is! Map) return null;
    final map = Map<String, dynamic>.from(rawErrors);

    String? firstCode(String key) {
      final value = map[key];
      if (value is List && value.isNotEmpty && value.first is String) {
        return value.first as String;
      }
      if (value is String && value.isNotEmpty) {
        return value;
      }
      return null;
    }

    String? mapField(String key, String fallback) {
      final code = firstCode(key);
      if (code == null) return null;
      return switch (code) {
        'MSG01' => OperatorProfileMessages.requiredField,
        'MSG02' => OperatorProfileMessages.invalidEmail,
        'MSG04' => OperatorProfileMessages.invalidPhone,
        'MSG19' => OperatorProfileMessages.invalidLogo,
        _ => fallback,
      };
    }

    final parsed = OperatorProfileValidationErrors(
      businessName: mapField(
        'businessName',
        OperatorProfileMessages.businessNameTooLong,
      ),
      businessDescription: mapField(
        'businessDescription',
        OperatorProfileMessages.descriptionTooLong,
      ),
      businessAddress: mapField(
        'businessAddress',
        OperatorProfileMessages.addressTooLong,
      ),
      contactPhone: mapField(
        'contactPhone',
        OperatorProfileMessages.invalidPhone,
      ),
      contactEmail: mapField(
        'contactEmail',
        OperatorProfileMessages.invalidEmail,
      ),
      website: mapField('website', OperatorProfileMessages.invalidWebsite),
      logo: mapField('logo', OperatorProfileMessages.invalidLogo),
      removeLogo: mapField(
        'removeLogo',
        OperatorProfileMessages.invalidRemoveLogo,
      ),
    );

    return parsed.isEmpty ? null : parsed;
  }
}
