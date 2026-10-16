import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/constants/api_constants.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/traveler/data/models/mapbox_directions_model.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_route.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/route_directions_repository.dart';

/// Mapbox Directions client. It uses its own [Dio] without the TripMate auth
/// or logging interceptors, so the TripMate token is never sent to Mapbox and
/// the Mapbox token never reaches logs.
final class MapboxDirectionsRepositoryImpl
    implements RouteDirectionsRepository {
  MapboxDirectionsRepositoryImpl({required String accessToken, Dio? dio})
    : _accessToken = accessToken,
      _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://api.mapbox.com',
              connectTimeout: ApiConstants.connectTimeout,
              receiveTimeout: ApiConstants.receiveTimeout,
            ),
          );

  /// Mapbox has no motorbike profile; driving is the closest road network.
  /// Public transit is not offered by Mapbox Directions and cannot be planned
  /// yet, so it also uses driving.
  static String profileFor(TransportMode? mode) => switch (mode) {
    TransportMode.walking => 'mapbox/walking',
    TransportMode.motorbike ||
    TransportMode.car ||
    TransportMode.publicTransit ||
    null => 'mapbox/driving',
  };

  final String _accessToken;
  final Dio _dio;

  @override
  bool get isAvailable => true;

  @override
  Future<NavigationRoute> getRoute({
    required NavigationCoordinate origin,
    required NavigationCoordinate destination,
    TransportMode? transportMode,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/directions/v5/${profileFor(transportMode)}/'
        '${origin.longitude},${origin.latitude};'
        '${destination.longitude},${destination.latitude}',
        queryParameters: {
          'alternatives': 'false',
          'geometries': 'geojson',
          'overview': 'full',
          'steps': 'true',
          'language': 'en',
          'access_token': _accessToken,
        },
      );
      final data = response.data;
      if (data == null) throw const FormatException('Empty directions.');
      return MapboxDirectionsModel.fromJson(data);
    } on DioException catch (error) {
      if (error.response == null) throw const NetworkFailure();
      throw const RoutingProviderFailure();
    } on FormatException {
      throw const RoutingProviderFailure('No route was found to this stop.');
    }
  }
}

/// Used when no Mapbox token is configured: guidance is disabled, navigation
/// sessions still work with straight-line distance.
final class UnavailableRouteDirectionsRepository
    implements RouteDirectionsRepository {
  const UnavailableRouteDirectionsRepository();

  @override
  bool get isAvailable => false;

  @override
  Future<NavigationRoute> getRoute({
    required NavigationCoordinate origin,
    required NavigationCoordinate destination,
    TransportMode? transportMode,
  }) async => throw const RoutingProviderFailure(
    'Turn-by-turn guidance is not configured.',
  );
}
