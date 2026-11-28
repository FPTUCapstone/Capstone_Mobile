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

/// A category from the server catalogue (`GET /api/v1/tour-categories`).
final class TourCategoryOption extends Equatable {
  const TourCategoryOption({
    required this.id,
    required this.code,
    required this.name,
  });
  final int id;
  final String code;
  final String name;
  @override
  List<Object?> get props => [id, code, name];
}

/// The server catalogues a draft must reference (BR-101).
final class TourPackageOptions extends Equatable {
  const TourPackageOptions({
    required this.destinations,
    required this.policies,
    this.categories = const [],
  });
  final List<TourDestinationOption> destinations;
  final List<CancellationPolicyOption> policies;
  final List<TourCategoryOption> categories;
  @override
  List<Object?> get props => [destinations, policies, categories];
}
