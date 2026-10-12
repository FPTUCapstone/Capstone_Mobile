import 'package:equatable/equatable.dart';

final class EligibleCouponTour extends Equatable {
  const EligibleCouponTour({
    required this.id,
    required this.title,
    required this.destination,
    required this.basePrice,
  });

  final int id;
  final String title;
  final String? destination;
  final num basePrice;

  @override
  List<Object?> get props => [id, title, destination, basePrice];
}
