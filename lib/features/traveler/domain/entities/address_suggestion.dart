import 'package:equatable/equatable.dart';

/// A search suggestion for a starting point. It has no coordinates yet; they
/// are fetched only for the one the Traveler picks.
final class AddressCandidate extends Equatable {
  const AddressCandidate({
    required this.id,
    required this.name,
    required this.fullAddress,
  });

  /// The provider's identifier used to resolve the suggestion.
  final String id;
  final String name;
  final String fullAddress;

  @override
  List<Object> get props => [id, name, fullAddress];
}

/// An address or named place (hotel, school, street) the Traveler can use as a
/// starting point.
final class AddressSuggestion extends Equatable {
  const AddressSuggestion({
    required this.name,
    required this.fullAddress,
    required this.latitude,
    required this.longitude,
  });

  final String name;

  /// Where it is; for a named place this usually omits the [name].
  final String fullAddress;
  final double latitude;
  final double longitude;

  /// The starting-point text: the name followed by its address when the
  /// address does not already start with it.
  String get label =>
      fullAddress.startsWith(name) ? fullAddress : '$name, $fullAddress';

  @override
  List<Object> get props => [name, fullAddress, latitude, longitude];
}
