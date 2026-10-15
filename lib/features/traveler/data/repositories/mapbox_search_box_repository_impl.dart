import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/constants/api_constants.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/location/device_location_service.dart';
import 'package:trip_mate_mobile/features/traveler/data/models/mapbox_search_box_model.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/address_suggestion.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/address_search_repository.dart';
import 'package:uuid/uuid.dart';

/// Mapbox Search Box client for starting points: street addresses as well as
/// named places such as hotels or schools. Suggestions are free text only; the
/// picked one is resolved to coordinates with `retrieve`, both under one
/// Mapbox search session. Like the Directions client it uses its own [Dio], so
/// the TripMate token is never sent to Mapbox and the Mapbox token never
/// reaches logs.
final class MapboxSearchBoxRepositoryImpl implements AddressSearchRepository {
  MapboxSearchBoxRepositoryImpl({
    required String accessToken,
    Dio? dio,
    String Function()? newSessionToken,
  }) : _accessToken = accessToken,
       _newSessionToken = newSessionToken ?? const Uuid().v4,
       _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: 'https://api.mapbox.com',
               connectTimeout: ApiConstants.connectTimeout,
               receiveTimeout: ApiConstants.receiveTimeout,
             ),
           );

  static const resultLimit = 8;

  /// Locations only: categories and brands would resolve to an arbitrary place.
  static const resultTypes = 'poi,address,street,neighborhood,locality,place';
  static const _unavailableMessage = 'Address search is unavailable right now.';

  final String _accessToken;
  final String Function() _newSessionToken;
  final Dio _dio;

  /// Groups suggestions and the final retrieve into one Mapbox session.
  String? _sessionToken;

  @override
  bool get isAvailable => true;

  @override
  Future<List<AddressCandidate>> suggest(
    String query, {
    DeviceLocation? near,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    final data = await _get('/search/searchbox/v1/suggest', {
      'q': trimmed,
      // TripMate plans trips in Vietnam only.
      'country': 'vn',
      'language': 'vi',
      'limit': resultLimit,
      'types': resultTypes,
      if (near != null) 'proximity': '${near.longitude},${near.latitude}',
    });
    return _parse(() => MapboxSearchBoxModel.suggestions(data));
  }

  @override
  Future<AddressSuggestion> resolve(AddressCandidate candidate) async {
    final data = await _get(
      '/search/searchbox/v1/retrieve/${Uri.encodeComponent(candidate.id)}',
      {'language': 'vi'},
    );
    // A retrieve closes the session; the next search starts a new one.
    _sessionToken = null;
    return _parse(() => MapboxSearchBoxModel.retrieved(data));
  }

  Future<Map<String, dynamic>> _get(
    String path,
    Map<String, Object> queryParameters,
  ) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: {
          ...queryParameters,
          'session_token': _sessionToken ??= _newSessionToken(),
          'access_token': _accessToken,
        },
      );
      final data = response.data;
      if (data == null) throw const ServerFailure(_unavailableMessage);
      return data;
    } on DioException catch (error) {
      throw error.type == DioExceptionType.badResponse
          ? const ServerFailure(_unavailableMessage)
          : const NetworkFailure();
    }
  }

  T _parse<T>(T Function() parse) {
    try {
      return parse();
    } on FormatException {
      throw const ServerFailure(_unavailableMessage);
    }
  }
}

/// Used when no Mapbox token is configured: only catalog places can be chosen.
final class UnavailableAddressSearchRepository
    implements AddressSearchRepository {
  const UnavailableAddressSearchRepository();

  @override
  bool get isAvailable => false;

  @override
  Future<List<AddressCandidate>> suggest(
    String query, {
    DeviceLocation? near,
  }) async => const [];

  @override
  Future<AddressSuggestion> resolve(AddressCandidate candidate) =>
      throw const ServerFailure('Address search is not configured.');
}
