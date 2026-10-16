import 'package:equatable/equatable.dart';

/// A destination from the server catalogue (`GET /api/v1/destinations`).
final class TourDestinationOption extends Equatable {
  const TourDestinationOption({required this.id, required this.name});
  final int id;
  final String name;
  @override
  List<Object?> get props => [id, name];
}

/// An active cancellation-policy template an operator can attach to a package.
final class CancellationPolicyOption extends Equatable {
  const CancellationPolicyOption({
    required this.id,
    required this.name,
    this.description,
  });
  final int id;
  final String name;
  final String? description;
  @override
  List<Object?> get props => [id, name, description];
}

/// The server catalogues a draft must reference (BR-101).
final class TourPackageOptions extends Equatable {
  const TourPackageOptions({
    required this.destinations,
    required this.policies,
  });
  final List<TourDestinationOption> destinations;
  final List<CancellationPolicyOption> policies;
  @override
  List<Object?> get props => [destinations, policies];
}
