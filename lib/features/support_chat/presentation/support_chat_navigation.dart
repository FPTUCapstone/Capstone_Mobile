import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/features/support_chat/domain/entities/support_chat.dart';

/// Converts server Web destinations into the mobile routes we support.
abstract final class SupportChatNavigation {
  static String? locationFor(String url) {
    if (url == '/tours') return AppRoutes.tourSearch;
    if (url == '/plan') return AppRoutes.createItinerary;
    if (url == '/pois') return AppRoutes.explore;
    if (url == '/account/profile') return AppRoutes.travelerProfile;
    if (url == '/account/preferences') return AppRoutes.travelerPreferences;
    if (url == '/account/security') return AppRoutes.travelerChangePassword;
    if (url == '/account/trips') return AppRoutes.tripHistory;
    final tour = RegExp(r'^/tours/([0-9]+)$').firstMatch(url);
    if (tour != null) {
      final id = _id(tour[1]!);
      return id == null ? null : AppRoutes.tourDetail(id);
    }
    final itinerary = RegExp(r'^/itinerary/([0-9]+)$').firstMatch(url);
    if (itinerary != null) {
      final id = _id(itinerary[1]!);
      return id == null ? null : AppRoutes.itineraryDetailPath(int.parse(id));
    }
    final refund = RegExp(r'^/bookings/([0-9]+)/refund$').firstMatch(url);
    if (refund != null) {
      final id = _id(refund[1]!);
      return id == null ? null : AppRoutes.bookingRefund(id);
    }
    final booking = RegExp(r'^/tours/([0-9]+)/book\?([^?]+)$').firstMatch(url);
    if (booking != null) {
      final tourId = _id(booking[1]!);
      if (tourId == null) return null;
      final parameters = <String, String>{};
      for (final pair in booking[2]!.split('&')) {
        if (!RegExp(
          r'^(scheduleId|adults|children|infants)=[0-9]+$',
        ).hasMatch(pair)) {
          return null;
        }
        final parts = pair.split('=');
        if (parameters.containsKey(parts[0])) return null;
        parameters[parts[0]] = parts[1];
      }
      final scheduleId = _id(parameters['scheduleId'] ?? '');
      if (scheduleId == null) return null;
      final rawAdults = parameters['adults'];
      final adults = rawAdults == null ? null : int.tryParse(rawAdults);
      if (rawAdults != null && (adults == null || adults < 1 || adults > 50)) {
        return null;
      }
      final children = parameters.containsKey('children')
          ? int.tryParse(parameters['children']!)
          : null;
      final infants = parameters.containsKey('infants')
          ? int.tryParse(parameters['infants']!)
          : null;
      if ((parameters.containsKey('children') && children == null) ||
          (parameters.containsKey('infants') && infants == null) ||
          ((children != null || infants != null) && adults == null) ||
          (adults ?? 0) + (children ?? 0) + (infants ?? 0) > 50) {
        return null;
      }
      return AppRoutes.bookTour(
        tourId,
        scheduleId,
        adults: adults,
        children: children,
        infants: infants,
      );
    }
    return null;
  }

  static String? _id(String value) {
    if (!SupportChatContext(kind: 'refund', id: value).isValid) return null;
    return BigInt.parse(value).toString();
  }
}
