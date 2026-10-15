import 'package:trip_mate_mobile/core/location/device_location_service.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/address_suggestion.dart';

abstract interface class AddressSearchRepository {
  /// Whether free-text address search is configured.
  bool get isAvailable;

  /// Suggests addresses and named places matching [query], ranked closer to
  /// [near] when given.
  Future<List<AddressCandidate>> suggest(String query, {DeviceLocation? near});

  /// Fetches the coordinates of the [candidate] the Traveler picked.
  Future<AddressSuggestion> resolve(AddressCandidate candidate);
}
