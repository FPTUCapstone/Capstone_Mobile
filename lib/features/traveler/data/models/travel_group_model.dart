import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group.dart';

/// JSON data transfer object for the travel group API response.
///
/// Input: raw JSON map from POST /api/v1/travel-groups.
/// Output: domain [TravelGroup] via [toEntity].
final class TravelGroupModel {
  const TravelGroupModel({
    required this.id,
    required this.name,
    required this.inviteCode,
  });

  factory TravelGroupModel.fromJson(Map<String, dynamic> json) {
    return TravelGroupModel(
      id: (json['groupId'] ?? json['id'] ?? 0) as int,
      name: (json['groupName'] ?? json['name'] ?? '') as String,
      inviteCode: (json['inviteCode'] ?? '') as String,
    );
  }

  final int id;
  final String name;
  final String inviteCode;

  /// Converts this model to the domain entity.
  TravelGroup toEntity() =>
      TravelGroup(id: id, name: name, inviteCode: inviteCode);
}
