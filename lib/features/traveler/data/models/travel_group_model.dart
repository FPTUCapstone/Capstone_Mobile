import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group.dart';

/// JSON data transfer object for the travel group API response.
///
/// Input: raw JSON map from travel group endpoints.
/// Output: domain [TravelGroup] via [toEntity].
final class TravelGroupModel {
  const TravelGroupModel({
    required this.id,
    required this.name,
    required this.itineraryId,
    this.inviteCode,
  });

  factory TravelGroupModel.fromJson(Map<String, dynamic> json) {
    final id = json['groupId'];
    final name = json['groupName'];
    final inviteCode = json['inviteCode'];
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
    if (itineraryId is! int || itineraryId <= 0) {
      throw const FormatException(
        'Travel group response has an invalid itineraryId.',
      );
    }

    return TravelGroupModel(
      id: id,
      name: name.trim(),
      inviteCode: inviteCode is String ? inviteCode.trim() : null,
      itineraryId: itineraryId,
    );
  }

  final int id;
  final String name;
  final int itineraryId;
  final String? inviteCode;

  /// Converts this model to the domain entity.
  TravelGroup toEntity() => TravelGroup(
    id: id,
    name: name,
    inviteCode: inviteCode,
    itineraryId: itineraryId,
  );
}
