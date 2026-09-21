import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group.dart';

/// JSON data transfer object for the travel group API response.
///
/// Input: raw JSON map from POST /api/v1/travel-groups.
/// Output: domain [TravelGroup] via [toEntity].
final class TravelGroupModel {
  const TravelGroupModel({
    required this.id,
    required this.name,
    this.itineraryId,
  });

  factory TravelGroupModel.fromJson(Map<String, dynamic> json) {
    final id = json['groupId'];
    final name = json['groupName'];
    final itineraryId = json['itineraryId'];
    if (id is! int || id <= 0) {
      throw const FormatException(
        'Travel group response has an invalid groupId.',
      );
    }
    if (name is! String || name.trim().isEmpty) {
      throw const FormatException(
        'Travel group response has an invalid groupName.',
      );
    }
    return TravelGroupModel(
      id: id,
      name: name.trim(),
      itineraryId: itineraryId is int ? itineraryId : null,
    );
  }

  final int id;
  final String name;
  final int? itineraryId;

  /// Converts this model to the domain entity.
  TravelGroup toEntity() =>
      TravelGroup(id: id, name: name, itineraryId: itineraryId);
}
