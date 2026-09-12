import 'package:equatable/equatable.dart';

/// Immutable domain entity representing a travel group.
///
/// Input: primitive fields from API response.
/// Output: strongly-typed value object used across domain and presentation.
final class TravelGroup extends Equatable {
  const TravelGroup({
    required this.id,
    required this.name,
    required this.inviteCode,
  });

  final int id;
  final String name;
  final String inviteCode;

  @override
  List<Object?> get props => [id, name, inviteCode];
}
