import 'package:trip_mate_mobile/features/traveler/domain/entities/address_suggestion.dart';

/// Parses Mapbox Search Box responses. Entries without a usable identifier,
/// name, or point are skipped rather than failing the whole search.
abstract final class MapboxSearchBoxModel {
  /// Category and brand suggestions stand for many places, not one location.
  static const _nonLocationTypes = {'category', 'brand'};

  static List<AddressCandidate> suggestions(Map<String, dynamic> json) {
    final suggestions = json['suggestions'];
    if (suggestions is! List) {
      throw const FormatException('Invalid place suggestion response.');
    }
    return suggestions
        .map(_candidate)
        .whereType<AddressCandidate>()
        .toList(growable: false);
  }

  /// The first usable feature of a `retrieve` response.
  static AddressSuggestion retrieved(Map<String, dynamic> json) {
    final features = json['features'];
    if (features is! List) {
      throw const FormatException('Invalid place response.');
    }
    final place = features.map(_place).whereType<AddressSuggestion>();
    if (place.isEmpty) {
      throw const FormatException('The place has no location.');
    }
    return place.first;
  }

  static AddressCandidate? _candidate(Object? value) {
    if (value is! Map<String, dynamic> ||
        _nonLocationTypes.contains(value['feature_type'])) {
      return null;
    }
    final id = _text(value['mapbox_id']);
    final name = _text(value['name']);
    if (id == null || name == null) return null;
    return AddressCandidate(
      id: id,
      name: name,
      fullAddress: _address(value) ?? name,
    );
  }

  static AddressSuggestion? _place(Object? feature) {
    if (feature is! Map<String, dynamic>) return null;
    final properties = feature['properties'];
    final geometry = feature['geometry'];
    if (properties is! Map<String, dynamic> ||
        geometry is! Map<String, dynamic>) {
      return null;
    }
    final coordinates = geometry['coordinates'];
    final name = _text(properties['name']);
    if (coordinates is! List ||
        coordinates.length < 2 ||
        coordinates[0] is! num ||
        coordinates[1] is! num ||
        name == null) {
      return null;
    }
    return AddressSuggestion(
      name: name,
      fullAddress: _address(properties) ?? name,
      // GeoJSON points are [longitude, latitude].
      latitude: (coordinates[1] as num).toDouble(),
      longitude: (coordinates[0] as num).toDouble(),
    );
  }

  // Places carry `full_address`; streets and areas only `place_formatted`.
  // Mapbox leaves the ward out of both in Vietnam ("Đào Tấn, Đà Nẵng, 50500"),
  // which makes branches of one chain hard to tell apart, so the ward from
  // `context` is put back after the street.
  static String? _address(Map<String, dynamic> json) {
    final address =
        _text(json['full_address']) ?? _text(json['place_formatted']);
    final ward = _ward(json['context']);
    if (address == null || ward == null || address.contains(ward)) {
      return address;
    }
    final separator = address.indexOf(', ');
    return separator < 0
        ? '$address, $ward'
        : '${address.substring(0, separator)}, $ward'
              '${address.substring(separator)}';
  }

  static String? _ward(Object? context) {
    if (context is! Map<String, dynamic>) return null;
    for (final key in const ['neighborhood', 'locality']) {
      final level = context[key];
      if (level is Map<String, dynamic>) {
        final name = _text(level['name']);
        if (name != null) return name;
      }
    }
    return null;
  }

  static String? _text(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;
}
